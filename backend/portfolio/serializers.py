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
    ebics_credential = serializers.SerializerMethodField()

    class Meta:
        model = FinancialAccount
        fields = [
            'id', 'name', 'broker', 'broker_code', 'account_identifier',
            'account_type', 'currency', 'is_manual', 'status',
            'sync_enabled', 'last_sync_at', 'last_sync_error',
            'latest_snapshot', 'ebics_credential', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'status', 'last_sync_at', 'last_sync_error',
                           'created_at', 'updated_at']

    def get_ebics_credential(self, obj):
        if obj.ebics_credential_id:
            c = obj.ebics_credential
            return {'id': c.id, 'label': c.label, 'state': c.state}
        return None

    def update(self, instance, validated_data):
        old_broker_id = instance.broker_id
        account = super().update(instance, validated_data)

        # Security: changing the broker (incl. switching to/from manual) must never
        # carry stored credentials across. Drop them entirely so the user has to
        # re-enter them, even if they later migrate back to the original broker.
        if account.broker_id != old_broker_id:
            account.encrypted_credentials = None
            account.pending_auth_state = None
            account.last_sync_error = ''
            account.status = 'active' if account.is_manual else 'pending_auth'
            account.save(update_fields=[
                'encrypted_credentials', 'pending_auth_state',
                'last_sync_error', 'status',
            ])
        return account


class FinancialAccountCreateSerializer(serializers.ModelSerializer):
    broker_code = serializers.SlugRelatedField(
        slug_field='code',
        queryset=BrokerSerializer.Meta.model.objects.filter(is_active=True),
        source='broker'
    )
    credentials = serializers.JSONField(write_only=True, required=False)
    ebics_credential_id = serializers.IntegerField(
        write_only=True, required=False, allow_null=True
    )

    class Meta:
        model = FinancialAccount
        fields = [
            'name', 'broker_code', 'account_identifier', 'account_type',
            'currency', 'is_manual', 'sync_enabled', 'credentials',
            'ebics_credential_id'
        ]

    def create(self, validated_data):
        # Remove credentials - they will be encrypted by the view using KEK
        credentials = validated_data.pop('credentials', None)

        # Link to a shared EBICS subscriber credential (validated for ownership).
        ebics_credential_id = validated_data.pop('ebics_credential_id', None)
        if ebics_credential_id is not None:
            from brokers.models import EbicsCredential
            request = self.context.get('request')
            user = getattr(request, 'user', None)
            try:
                validated_data['ebics_credential'] = EbicsCredential.objects.get(
                    pk=ebics_credential_id, user=user,
                )
            except EbicsCredential.DoesNotExist:
                raise serializers.ValidationError(
                    {'ebics_credential_id': 'EBICS credential not found'}
                )

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
