import base64
import logging

from django.db import IntegrityError
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.kek_auth import KEKAuthenticationMixin

from .models import Broker, EbicsCredential
from .serializers import (
    BrokerSerializer,
    EbicsCredentialCreateSerializer,
    EbicsCredentialSerializer,
)

logger = logging.getLogger(__name__)


class BrokerListView(generics.ListAPIView):
    """List all active brokers."""
    serializer_class = BrokerSerializer
    permission_classes = [IsAuthenticated]
    queryset = Broker.objects.filter(is_active=True)


class BrokerDetailView(generics.RetrieveAPIView):
    """Get broker details by code."""
    serializer_class = BrokerSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'code'
    queryset = Broker.objects.filter(is_active=True)


# ---------------------------------------------------------------------------
# EBICS credential management (e.g. ZKB). Subscriber-level credentials shared
# across accounts; the RSA keyring is stored Fernet-under-KEK like all secrets.
# ---------------------------------------------------------------------------

def _letter_payload(cred, letter) -> dict:
    ext = 'pdf' if 'pdf' in letter.media_type else 'html'
    return {
        'media_type': letter.media_type,
        'filename': f'ebics-init-letter-{cred.partner_id}.{ext}',
        'content_base64': base64.b64encode(letter.content).decode(),
    }


def _signed_balance(bal):
    """(amount, currency, date) with sign from CRDT/DBIT for a camt Balance."""
    from ebicsclient import CreditDebit
    amount = bal.amount if bal.credit_debit == CreditDebit.CREDIT else -bal.amount
    return amount, bal.currency, bal.date


class EbicsCredentialListCreateView(KEKAuthenticationMixin, APIView):
    """List EBICS credentials, or create one (generating a fresh RSA keyring)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        creds = EbicsCredential.objects.filter(user=request.user).select_related('broker')
        return Response(EbicsCredentialSerializer(creds, many=True).data)

    def post(self, request):
        from .integrations.zkb_ebics import generate_keyring_blob

        serializer = EbicsCredentialCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            broker = Broker.objects.get(code=data['broker_code'], is_active=True)
        except Broker.DoesNotExist:
            return Response({'error': 'Unknown broker'}, status=status.HTTP_400_BAD_REQUEST)
        if broker.integration_type != 'ebics':
            return Response(
                {'error': f'Broker {broker.code} does not use EBICS'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # The EBICS endpoint URL comes from the broker's configured api_base_url — never
        # from client input — so a user cannot point the server at an arbitrary host (SSRF).
        url = broker.api_base_url
        if not url:
            return Response(
                {'error': f'Broker {broker.code} has no EBICS URL configured'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Generate the keyring and encrypt it under the user's KEK before storing.
        blob = generate_keyring_blob()
        encrypted_keyring = self.encrypt_blob(request, blob)

        try:
            cred = EbicsCredential.objects.create(
                user=request.user,
                broker=broker,
                label=data['label'],
                host_id=data['host_id'],
                partner_id=data['partner_id'],
                subscriber_id=data['user_id'],
                url=url,
                bank_hash_auth=(data.get('bank_hash_auth') or '').replace(' ', '').lower(),
                bank_hash_enc=(data.get('bank_hash_enc') or '').replace(' ', '').lower(),
                encrypted_keyring=encrypted_keyring,
                state='new',
            )
        except IntegrityError:
            return Response(
                {'error': 'An EBICS credential with this host/partner/user already exists'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            EbicsCredentialSerializer(cred).data, status=status.HTTP_201_CREATED,
        )


class EbicsCredentialDetailView(KEKAuthenticationMixin, APIView):
    """Retrieve, update (label/hashes), or delete an EBICS credential."""
    permission_classes = [IsAuthenticated]

    def _get(self, request, pk):
        return EbicsCredential.objects.filter(user=request.user).select_related('broker').get(pk=pk)

    def get(self, request, pk):
        try:
            cred = self._get(request, pk)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(EbicsCredentialSerializer(cred).data)

    def patch(self, request, pk):
        try:
            cred = self._get(request, pk)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        # url is intentionally NOT patchable — it is bank infrastructure sourced from
        # the broker, not user-editable (avoids repointing the server at an arbitrary host).
        if 'label' in request.data:
            cred.label = request.data['label']
        for field in ('bank_hash_auth', 'bank_hash_enc'):
            if field in request.data:
                setattr(cred, field, (request.data[field] or '').replace(' ', '').lower())
        cred.save()
        return Response(EbicsCredentialSerializer(cred).data)

    def delete(self, request, pk):
        try:
            cred = self._get(request, pk)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        linked = cred.accounts.count()
        if linked:
            return Response(
                {'error': f'{linked} account(s) still use this credential. Remove them first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        cred.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class EbicsCredentialInitializeView(KEKAuthenticationMixin, APIView):
    """Send INI + HIA and return the initialisation letter to print, sign and mail."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from .integrations.zkb_ebics import (
            EbicsSubscriberBlockedError,
            submit_keys_and_letter,
        )

        try:
            cred = EbicsCredential.objects.get(pk=pk, user=request.user)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if not cred.encrypted_keyring:
            return Response({'error': 'Credential has no keyring'}, status=status.HTTP_400_BAD_REQUEST)

        blob = self.decrypt_blob(request, cred.encrypted_keyring)
        try:
            ini_state, hia_state, letter = submit_keys_and_letter(cred, blob)
        except EbicsSubscriberBlockedError as e:
            # The bank rejected our fresh keys as already-initialised (091002): the keys
            # did NOT reach the bank, so there is no valid letter to mail. Mark the
            # credential errored and tell the user the bank must reset the subscriber
            # first. Do NOT advance to 'keys_sent' or return a letter.
            logger.warning('EBICS keys not delivered for credential %s: %s', cred.id, e)
            cred.state = 'error'
            cred.last_error = str(e)
            cred.save(update_fields=['state', 'last_error', 'updated_at'])
            return Response(
                {'error': str(e),
                 'code': 'subscriber_blocked',
                 'hint': 'Contact the bank and ask them to reset (delete) your EBICS '
                         'subscriber, then submit keys again. Do not mail any letter '
                         'downloaded before the reset — its key fingerprints will not '
                         'match the keys the bank holds and activation will fail.'},
                status=status.HTTP_409_CONFLICT,
            )
        except Exception as e:
            logger.exception('EBICS INI/HIA failed for credential %s', cred.id)
            cred.last_error = str(e) or repr(e)
            cred.save(update_fields=['last_error', 'updated_at'])
            return Response(
                {'error': f'Key submission failed: {cred.last_error}'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        cred.state = 'keys_sent'
        cred.last_error = ''
        cred.save(update_fields=['state', 'last_error', 'updated_at'])

        return Response({
            'status': cred.state,
            'ini': ini_state.value,
            'hia': hia_state.value,
            'letter': _letter_payload(cred, letter),
            'message': 'Print and sign the letter, then mail it to the bank. '
                       'Once the bank activates your access, use "Test connection".',
        })


class EbicsCredentialLetterView(KEKAuthenticationMixin, APIView):
    """Re-render the initialisation letter (deterministic from the stored keys)."""
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        from .integrations.zkb_ebics import render_letter

        try:
            cred = EbicsCredential.objects.get(pk=pk, user=request.user)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if not cred.encrypted_keyring:
            return Response({'error': 'Credential has no keyring'}, status=status.HTTP_400_BAD_REQUEST)

        blob = self.decrypt_blob(request, cred.encrypted_keyring)
        letter = render_letter(cred, blob)
        return Response({'letter': _letter_payload(cred, letter)})


class EbicsCredentialTestView(KEKAuthenticationMixin, APIView):
    """Verify activation: HPB (pin bank keys) + camt.053 download; list discovered IBANs.

    On success marks the credential active and, if the bank-key hashes were not
    pre-pinned, records them (trust-on-first-use) for the user to verify against
    the paper letter.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from .integrations.zkb_ebics import fetch_bank_keys_and_statements

        try:
            cred = EbicsCredential.objects.get(pk=pk, user=request.user)
        except EbicsCredential.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        if not cred.encrypted_keyring:
            return Response({'error': 'Credential has no keyring'}, status=status.HTTP_400_BAD_REQUEST)

        blob = self.decrypt_blob(request, cred.encrypted_keyring)
        try:
            hashes_hex, statements = fetch_bank_keys_and_statements(cred, blob)
        except Exception as e:
            logger.exception('EBICS test failed for credential %s', cred.id)
            cred.last_error = str(e) or repr(e)
            cred.save(update_fields=['last_error', 'updated_at'])
            return Response(
                {'error': f'Connection test failed: {cred.last_error}',
                 'hint': 'If you have not yet mailed the signed letter, or the bank has '
                         'not activated it, this is expected — retry after activation.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # Trust-on-first-use: record the bank key hashes if not already pinned.
        tofu = False
        if not cred.bank_hash_auth or not cred.bank_hash_enc:
            cred.bank_hash_auth = hashes_hex['auth']
            cred.bank_hash_enc = hashes_hex['enc']
            tofu = True
        cred.state = 'active'
        cred.last_error = ''
        cred.save()

        accounts = []
        for stmt in statements:
            if not stmt.iban:
                continue
            bal = stmt.closing_balance or (stmt.balances[0] if stmt.balances else None)
            if bal is None:
                continue
            amount, currency, bal_date = _signed_balance(bal)
            accounts.append({
                'iban': stmt.iban,
                'currency': currency,
                'balance': float(amount),
                'date': bal_date.isoformat(),
            })

        return Response({
            'status': 'active',
            'bank_key_hashes': hashes_hex,
            'bank_key_hashes_recorded': tofu,
            'accounts': accounts,
            'message': 'Connection verified. You can now add accounts for the discovered IBANs.',
        })
