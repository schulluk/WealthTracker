"""ZKB (and other Swiss banks) via the EBICS 3.0 / H005 protocol.

Read-only: downloads camt.053 end-of-day statements and reports the closing
balance per IBAN. Uses the ``ebicsclient`` library.

Unlike the other integrations, the secret material (the RSA keyring) is not the
account's ``encrypted_credentials`` but a shared :class:`~brokers.models.EbicsCredential`.
The sync view decrypts that keyring and passes it in the ``credentials`` dict, so
this class stays stateless like its siblings. Expected keys:

    host_id, partner_id, user_id, url   — connection parameters
    bank_hash_auth, bank_hash_enc       — hex SHA-256 pinning hashes (optional)
    keyring_pem                         — base64 of the serialised ebicsclient keyring
    keyring_passphrase                  — passphrase for that keyring

The one-time key exchange (generate keys, INI/HIA, initialisation letter) lives in
the EBICS credential endpoints, not here — see brokers/views.py.
"""
import base64
import logging
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List

from .base import AccountInfo, AuthResult, BalanceInfo, BrokerIntegrationBase

logger = logging.getLogger(__name__)


class ZKBEbicsIntegration(BrokerIntegrationBase):
    """Download-only EBICS integration (camt.053 statements)."""

    def __init__(self, credentials: Dict[str, Any]):
        super().__init__(credentials)
        self._client = None
        self._statements = None  # cached list[Statement] for this instance

    # ---- client construction -------------------------------------------------

    def _build_client(self):
        """Reconstruct the ebicsclient Client from the decrypted credentials."""
        from ebicsclient import Bank, Client, User, deserialize_keyring

        keyring_pem = self.credentials.get('keyring_pem')
        passphrase = self.credentials.get('keyring_passphrase')
        if not keyring_pem or not passphrase:
            raise ValueError('EBICS keyring is missing — the credential is not initialized')

        keyring = deserialize_keyring(base64.b64decode(keyring_pem), passphrase)
        bank = Bank(host_id=self.credentials['host_id'], url=self.credentials['url'])
        user = User(partner_id=self.credentials['partner_id'], user_id=self.credentials['user_id'])
        return Client(bank, user, keyring)

    def _pinned_hashes(self):
        """BankKeyHashes from the stored hex hashes, or None for trust-on-first-use."""
        from ebicsclient import BankKeyHashes

        auth = self.credentials.get('bank_hash_auth')
        enc = self.credentials.get('bank_hash_enc')
        if auth and enc:
            return BankKeyHashes(
                authentication=bytes.fromhex(auth.replace(' ', '')),
                encryption=bytes.fromhex(enc.replace(' ', '')),
            )
        return None

    def _get_statements(self):
        """HPB (verifying pinned bank keys) then download+parse camt.053, cached."""
        if self._statements is not None:
            return self._statements
        if self._client is None:
            self._client = self._build_client()
        # Fetch and pin the bank's public keys, then pull the statements.
        self._client.hpb(pinned=self._pinned_hashes())
        self._statements = self._client.download_statements()
        return self._statements

    # ---- BrokerIntegrationBase ----------------------------------------------

    def authenticate(self) -> AuthResult:
        """EBICS has no interactive login: validate the keyring can be loaded.

        The actual network calls (HPB + download) happen lazily in get_accounts /
        get_balance so a construction problem surfaces as a clean error here.
        """
        try:
            self._client = self._build_client()
            return AuthResult(success=True)
        except Exception as e:
            logger.warning('EBICS client construction failed: %s', e)
            return AuthResult(success=False, error_message=str(e) or repr(e))

    def complete_2fa(self, auth_code, session_data) -> AuthResult:
        # Not applicable: EBICS access is granted out-of-band via the signed letter.
        return AuthResult(success=False, error_message='EBICS does not use interactive 2FA')

    def get_accounts(self) -> List[AccountInfo]:
        accounts = []
        for stmt in self._get_statements():
            if not stmt.iban:
                continue
            bal = stmt.closing_balance or (stmt.balances[0] if stmt.balances else None)
            accounts.append(AccountInfo(
                identifier=stmt.iban,
                name=stmt.iban,
                account_type='checking',
                currency=bal.currency if bal else 'CHF',
            ))
        return accounts

    def get_balance(self, account_identifier: str) -> BalanceInfo:
        statements = self._get_statements()

        matches = [s for s in statements if s.iban == account_identifier]
        if not matches:
            available = ', '.join(sorted({s.iban for s in statements if s.iban})) or 'none'
            raise ValueError(
                f'No camt.053 statement for IBAN {account_identifier}. '
                f'Available in this delivery: {available}'
            )

        # Use the most recent statement for this IBAN by closing-balance date.
        stmt = max(
            matches,
            key=lambda s: s.closing_balance.date if s.closing_balance else date.min,
        )
        bal = stmt.closing_balance
        if bal is None:
            raise ValueError(f'Statement for IBAN {account_identifier} has no closing balance')

        from ebicsclient import CreditDebit
        signed = bal.amount if bal.credit_debit == CreditDebit.CREDIT else -bal.amount

        return BalanceInfo(
            balance=Decimal(signed),
            currency=bal.currency,
            balance_date=bal.date,
            raw_data={
                'iban': stmt.iban,
                'balance_code': bal.code,
                'credit_debit': bal.credit_debit.value,
                'entries': len(stmt.entries),
                'source': 'ebics_camt053',
            },
        )


# ---------------------------------------------------------------------------
# One-time key-exchange helpers (used by the EBICS credential endpoints).
# Kept here so all ebicsclient usage lives in one module.
# ---------------------------------------------------------------------------

def generate_keyring_blob() -> Dict[str, str]:
    """Generate a fresh EBICS keyring and return the storable secret blob.

    The blob (serialised keyring + its passphrase) is what gets Fernet-encrypted
    under the user's KEK. The passphrase is random and never leaves the blob.
    """
    import secrets

    from ebicsclient import generate_keyring, serialize_keyring

    passphrase = secrets.token_urlsafe(32)
    keyring = generate_keyring()
    pem = serialize_keyring(keyring, passphrase)
    return {
        'keyring_pem': base64.b64encode(pem).decode(),
        'keyring_passphrase': passphrase,
    }


def _client_for(cred, blob):
    """Build an ebicsclient Client for an EbicsCredential + decrypted keyring blob."""
    from ebicsclient import Bank, Client, User, deserialize_keyring

    keyring = deserialize_keyring(base64.b64decode(blob['keyring_pem']), blob['keyring_passphrase'])
    bank = Bank(host_id=cred.host_id, url=cred.url)
    # NB: the EBICS user id is `subscriber_id`, NOT `cred.user_id` — the latter is the
    # Django `user` FK's integer PK (a non-str), which crashed ebicsclient during INI.
    user = User(partner_id=cred.partner_id, user_id=cred.subscriber_id)
    return Client(bank, user, keyring)


def _pinned_for(cred):
    from ebicsclient import BankKeyHashes

    if cred.bank_hash_auth and cred.bank_hash_enc:
        return BankKeyHashes(
            authentication=bytes.fromhex(cred.bank_hash_auth.replace(' ', '')),
            encryption=bytes.fromhex(cred.bank_hash_enc.replace(' ', '')),
        )
    return None


def submit_keys_and_letter(cred, blob):
    """Send INI + HIA and render the initialisation letter.

    Returns ``(ini_state, hia_state, letter)`` where letter is the ebicsclient
    Letter (``.media_type``, ``.content``). ``ini``/``hia`` are idempotent: the
    library reports ALREADY_INITIALISED rather than raising if keys were sent before.
    """
    from ebicsclient import OutputFormat

    client = _client_for(cred, blob)
    ini_state = client.ini()
    hia_state = client.hia()
    letter = client.make_ini_letter(output_format=OutputFormat.PDF, branding='Wealth Tracker')
    return ini_state, hia_state, letter


def render_letter(cred, blob):
    """Re-render the initialisation letter as PDF (deterministic from the keys)."""
    from ebicsclient import OutputFormat

    return _client_for(cred, blob).make_ini_letter(
        output_format=OutputFormat.PDF, branding='Wealth Tracker',
    )


def fetch_bank_keys_and_statements(cred, blob):
    """HPB (pinning) + camt.053 download. Returns ``(bank_key_hashes_hex, statements)``.

    ``bank_key_hashes_hex`` is ``{'auth': hex, 'enc': hex}`` computed from the keys the
    bank returned — for trust-on-first-use display/verification against the letter.
    Raises the underlying ebicsclient error if the bank has not activated the
    subscriber yet or the pinned hashes do not match.
    """
    from ebicsclient import bank_key_hashes

    client = _client_for(cred, blob)
    bank_keys = client.hpb(pinned=_pinned_for(cred))
    hashes = bank_key_hashes(bank_keys)
    statements = client.download_statements()
    return (
        {'auth': hashes.authentication.hex(), 'enc': hashes.encryption.hex()},
        statements,
    )
