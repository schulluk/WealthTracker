import base64
import secrets

from django.contrib.auth.models import User
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from core.encryption import decrypt_credentials as legacy_decrypt_credentials
from core.user_encryption import (
    decrypt_user_key,
    encrypt_credentials,
    encrypt_user_key,
    generate_salt,
    generate_user_key,
    pad_kek_for_fernet,
)
from portfolio.models import FinancialAccount

from .models import UserProfile
from .serializers import (
    PasswordChangeSerializer,
    RegisterSerializer,
    UserProfileSerializer,
    UserSerializer,
    UserUpdateSerializer,
)


class RegisterView(generics.CreateAPIView):
    """Register a new user."""
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            'message': 'User registered successfully'
        }, status=status.HTTP_201_CREATED)


class CurrentUserView(generics.RetrieveAPIView):
    """Get current authenticated user."""
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class UserProfileView(generics.RetrieveUpdateAPIView):
    """Get or update user profile."""
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.profile


class UserUpdateView(generics.UpdateAPIView):
    """Update user details (first_name, last_name, email)."""
    serializer_class = UserUpdateSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class PasswordChangeView(APIView):
    """Change user password."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PasswordChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'old_password': 'Current password is incorrect'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user.set_password(serializer.validated_data['new_password'])
        user.save()

        return Response({'message': 'Password changed successfully'})


class GetSaltView(APIView):
    """Get salts for a user (for client-side key derivation)."""
    permission_classes = [AllowAny]

    def get(self, request):
        username = request.query_params.get('username')
        if not username:
            return Response(
                {'error': 'username parameter required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            user = User.objects.get(username=username)
            profile = user.profile
        except User.DoesNotExist:
            # Return fake salts to prevent user enumeration
            return Response({
                'auth_salt': generate_salt(),
                'kek_salt': generate_salt(),
                'migrated': False,
            })

        if profile.encryption_migrated and profile.auth_salt and profile.kek_salt:
            return Response({
                'auth_salt': profile.auth_salt,
                'kek_salt': profile.kek_salt,
                'migrated': True,
            })
        else:
            # User not migrated - generate salts for them to use
            return Response({
                'auth_salt': generate_salt(),
                'kek_salt': generate_salt(),
                'migrated': False,
            })


class GenerateNewSaltView(APIView):
    """Generate new salts for password change."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        return Response({
            'new_auth_salt': generate_salt(),
            'new_kek_salt': generate_salt(),
        })


class LoginView(APIView):
    """
    Custom login view supporting both legacy and KEK-based authentication.

    For non-migrated users: accepts username + password
    For migrated users: accepts username + auth_hash
    """
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')
        auth_hash = request.data.get('auth_hash')

        if not username:
            return Response(
                {'error': 'username required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        profile = user.profile

        # Check authentication method
        if profile.encryption_migrated and auth_hash:
            # KEK-based authentication
            if not secrets.compare_digest(auth_hash, profile.auth_hash):
                return Response(
                    {'error': 'Invalid credentials'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        elif password:
            # Legacy password authentication
            if not user.check_password(password):
                return Response(
                    {'error': 'Invalid credentials'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
        else:
            return Response(
                {'error': 'password or auth_hash required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Generate tokens
        refresh = RefreshToken.for_user(user)

        response_data = {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data,
            'encryption_migrated': profile.encryption_migrated,
        }

        # Include encrypted_user_key for migrated users
        if profile.encryption_migrated and profile.encrypted_user_key:
            response_data['encrypted_user_key'] = base64.b64encode(
                bytes(profile.encrypted_user_key)
            ).decode()

        return Response(response_data)


class SetupEncryptionView(APIView):
    """
    Set up per-user encryption for a user.

    Called after login for non-migrated users to migrate them.
    Requires the user to be authenticated and provide:
    - kek: The Key Encryption Key (client-derived from password)
    - auth_hash: The authentication hash (client-derived from password)
    - auth_salt: The salt used to derive auth_hash
    - kek_salt: The salt used to derive KEK
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        profile = request.user.profile

        if profile.encryption_migrated:
            return Response(
                {'error': 'User already migrated'},
                status=status.HTTP_400_BAD_REQUEST
            )

        kek_b64 = request.data.get('kek')
        auth_hash = request.data.get('auth_hash')
        auth_salt = request.data.get('auth_salt')
        kek_salt = request.data.get('kek_salt')

        if not all([kek_b64, auth_hash, auth_salt, kek_salt]):
            return Response(
                {'error': 'kek, auth_hash, auth_salt, and kek_salt required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            kek = base64.b64decode(kek_b64)
            kek = pad_kek_for_fernet(kek)
        except Exception:
            return Response(
                {'error': 'Invalid KEK format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Generate a new user key and encrypt it with KEK
        user_key = generate_user_key()
        encrypted_user_key = encrypt_user_key(user_key, kek)

        # Re-encrypt all existing account credentials with the new user_key
        accounts_migrated = 0
        accounts_failed = []

        user_accounts = FinancialAccount.objects.filter(user=request.user)
        for account in user_accounts:
            if account.encrypted_credentials:
                try:
                    # Decrypt with legacy server-side key
                    credentials = legacy_decrypt_credentials(
                        account.encrypted_credentials
                    )
                    # Re-encrypt with new user key
                    account.encrypted_credentials = encrypt_credentials(
                        credentials, user_key
                    )
                    account.save(update_fields=['encrypted_credentials'])
                    accounts_migrated += 1
                except Exception as e:
                    accounts_failed.append({
                        'account': account.name,
                        'error': str(e)
                    })

        # Update profile (only after credentials are migrated)
        profile.encrypted_user_key = encrypted_user_key
        profile.auth_hash = auth_hash
        profile.auth_salt = auth_salt
        profile.kek_salt = kek_salt
        profile.encryption_migrated = True
        profile.save()

        response_data = {
            'status': 'success',
            'encrypted_user_key': base64.b64encode(encrypted_user_key).decode(),
            'accounts_migrated': accounts_migrated,
        }

        if accounts_failed:
            response_data['accounts_failed'] = accounts_failed

        return Response(response_data)


class KEKPasswordChangeView(APIView):
    """
    Change password with KEK re-encryption.

    For migrated users only. Re-encrypts the user key with the new KEK.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        profile = request.user.profile

        if not profile.encryption_migrated:
            return Response(
                {'error': 'User not migrated to KEK encryption'},
                status=status.HTTP_400_BAD_REQUEST
            )

        old_auth_hash = request.data.get('old_auth_hash')
        new_auth_hash = request.data.get('new_auth_hash')
        old_kek_b64 = request.data.get('old_kek')
        new_kek_b64 = request.data.get('new_kek')
        new_auth_salt = request.data.get('new_auth_salt')
        new_kek_salt = request.data.get('new_kek_salt')

        if not all([old_auth_hash, new_auth_hash, old_kek_b64, new_kek_b64,
                    new_auth_salt, new_kek_salt]):
            return Response(
                {'error': 'All fields required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verify old auth hash
        if not secrets.compare_digest(old_auth_hash, profile.auth_hash):
            return Response(
                {'error': 'Invalid current password'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            old_kek = pad_kek_for_fernet(base64.b64decode(old_kek_b64))
            new_kek = pad_kek_for_fernet(base64.b64decode(new_kek_b64))
        except Exception:
            return Response(
                {'error': 'Invalid KEK format'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Re-encrypt user key
        try:
            user_key = decrypt_user_key(profile.encrypted_user_key, old_kek)
            new_encrypted_user_key = encrypt_user_key(user_key, new_kek)
        except Exception:
            return Response(
                {'error': 'Failed to re-encrypt user key'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update profile
        profile.auth_hash = new_auth_hash
        profile.auth_salt = new_auth_salt
        profile.kek_salt = new_kek_salt
        profile.encrypted_user_key = new_encrypted_user_key
        profile.key_version += 1
        profile.save()

        return Response({
            'status': 'success',
            'encrypted_user_key': base64.b64encode(new_encrypted_user_key).decode(),
        })
