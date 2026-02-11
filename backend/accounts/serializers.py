from django.contrib.auth.models import User
from rest_framework import serializers

from .models import UserProfile


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = UserProfile
        fields = ['id', 'user', 'base_currency', 'auto_sync_enabled',
                  'send_weekly_report', 'default_chart_range', 'default_chart_granularity',
                  'last_sync_at', 'created_at', 'updated_at',
                  # Sync reminder settings
                  'sync_reminder_enabled', 'sync_reminder_hour', 'sync_reminder_minute',
                  'sync_on_app_open',
                  # Encryption status (read-only)
                  'encryption_migrated']
        read_only_fields = ['id', 'last_sync_at', 'created_at', 'updated_at', 'encryption_migrated']


class UserUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating user details."""
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email']


class PasswordChangeSerializer(serializers.Serializer):
    """Serializer for password change."""
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, min_length=8, write_only=True)
    new_password_confirm = serializers.CharField(required=True, write_only=True)

    def validate(self, data):
        if data['new_password'] != data['new_password_confirm']:
            raise serializers.ValidationError({
                'new_password_confirm': 'New passwords do not match'
            })
        return data


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)
    base_currency = serializers.ChoiceField(
        choices=UserProfile.CURRENCY_CHOICES,
        default='EUR',
        required=False
    )

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm', 'base_currency']

    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match'})
        return data

    def create(self, validated_data):
        base_currency = validated_data.pop('base_currency', 'EUR')
        validated_data.pop('password_confirm')
        user = User.objects.create_user(**validated_data)
        # Update the auto-created profile with base currency
        user.profile.base_currency = base_currency
        user.profile.save()
        return user
