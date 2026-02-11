from rest_framework import serializers

from brokers.serializers import BrokerSerializer

from .models import AccountSnapshot, FinancialAccount, PortfolioPosition


class PortfolioPositionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PortfolioPosition
        fields = [
            'id', 'symbol', 'isin', 'name', 'quantity',
            'price_per_unit', 'market_value', 'currency',
            'cost_basis', 'asset_class'
        ]


class AccountSnapshotSerializer(serializers.ModelSerializer):
    positions = PortfolioPositionSerializer(many=True, read_only=True)

    class Meta:
        model = AccountSnapshot
        fields = [
            'id', 'balance', 'currency', 'balance_base_currency',
            'base_currency', 'exchange_rate_used', 'snapshot_date',
            'snapshot_source', 'positions', 'created_at'
        ]
        read_only_fields = ['id', 'balance_base_currency', 'base_currency',
                           'exchange_rate_used', 'created_at']


class AccountSnapshotCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating manual snapshots."""
    class Meta:
        model = AccountSnapshot
        fields = ['balance', 'currency', 'snapshot_date']

    def create(self, validated_data):
        validated_data['snapshot_source'] = 'manual'
        return super().create(validated_data)


class FinancialAccountSerializer(serializers.ModelSerializer):
    broker = BrokerSerializer(read_only=True)
    broker_code = serializers.SlugRelatedField(
        slug_field='code',
        queryset=BrokerSerializer.Meta.model.objects.filter(is_active=True),
        write_only=True,
        source='broker'
    )
    latest_snapshot = AccountSnapshotSerializer(read_only=True)

    class Meta:
        model = FinancialAccount
        fields = [
            'id', 'name', 'broker', 'broker_code', 'account_identifier',
            'account_type', 'currency', 'is_manual', 'status',
            'sync_enabled', 'last_sync_at', 'last_sync_error',
            'latest_snapshot', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'status', 'last_sync_at', 'last_sync_error',
                           'created_at', 'updated_at']


class FinancialAccountCreateSerializer(serializers.ModelSerializer):
    broker_code = serializers.SlugRelatedField(
        slug_field='code',
        queryset=BrokerSerializer.Meta.model.objects.filter(is_active=True),
        source='broker'
    )
    credentials = serializers.JSONField(write_only=True, required=False)

    class Meta:
        model = FinancialAccount
        fields = [
            'name', 'broker_code', 'account_identifier', 'account_type',
            'currency', 'is_manual', 'sync_enabled', 'credentials'
        ]

    def create(self, validated_data):
        # Remove credentials - they will be encrypted by the view using KEK
        credentials = validated_data.pop('credentials', None)
        account = FinancialAccount.objects.create(**validated_data)

        # If credentials provided, encrypt them using KEK from request context
        if credentials:
            request = self.context.get('request')
            if request:
                from core.kek_auth import KEKAuthenticationMixin
                mixin = KEKAuthenticationMixin()
                account.encrypted_credentials = mixin.encrypt_account_credentials(
                    request, credentials
                )
                account.save()
        return account
