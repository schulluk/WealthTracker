from rest_framework import serializers

from .models import Broker, EbicsCredential


class BrokerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Broker
        fields = [
            'id', 'code', 'name', 'integration_type',
            'country', 'is_active', 'supports_2fa', 'supports_auto_sync',
            'credential_schema', 'logo_url', 'website_url', 'api_base_url'
        ]


class EbicsCredentialSerializer(serializers.ModelSerializer):
    """Read/list view of an EBICS credential. Never exposes the keyring."""
    broker_code = serializers.CharField(source='broker.code', read_only=True)
    broker_name = serializers.CharField(source='broker.name', read_only=True)
    user_id = serializers.CharField(source='subscriber_id', read_only=True)
    initialized = serializers.SerializerMethodField()
    account_count = serializers.SerializerMethodField()

    class Meta:
        model = EbicsCredential
        fields = [
            'id', 'label', 'broker_code', 'broker_name',
            'host_id', 'partner_id', 'user_id', 'url',
            'bank_hash_auth', 'bank_hash_enc',
            'state', 'last_error', 'initialized', 'account_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['state', 'last_error', 'created_at', 'updated_at']

    def get_initialized(self, obj) -> bool:
        return bool(obj.encrypted_keyring)

    def get_account_count(self, obj) -> int:
        return obj.accounts.count()


class EbicsCredentialCreateSerializer(serializers.Serializer):
    """Input for creating an EBICS credential (keyring is generated server-side)."""
    broker_code = serializers.CharField()
    label = serializers.CharField(max_length=100)
    host_id = serializers.CharField(max_length=64)
    partner_id = serializers.CharField(max_length=64)
    user_id = serializers.CharField(max_length=64)
    url = serializers.URLField()
    bank_hash_auth = serializers.CharField(required=False, allow_blank=True, default='')
    bank_hash_enc = serializers.CharField(required=False, allow_blank=True, default='')
