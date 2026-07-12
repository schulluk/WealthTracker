from django.contrib import admin

from .models import Broker, EbicsCredential


@admin.register(Broker)
class BrokerAdmin(admin.ModelAdmin):
    list_display = ['name', 'code', 'integration_type', 'country', 'is_active', 'supports_2fa']
    list_filter = ['integration_type', 'country', 'is_active']
    search_fields = ['name', 'code']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(EbicsCredential)
class EbicsCredentialAdmin(admin.ModelAdmin):
    # Never expose the encrypted keyring in the admin.
    list_display = ['label', 'user', 'broker', 'host_id', 'partner_id', 'state']
    list_filter = ['state', 'broker']
    search_fields = ['label', 'host_id', 'partner_id', 'subscriber_id']
    readonly_fields = ['created_at', 'updated_at', 'state', 'last_error']
    exclude = ['encrypted_keyring']
