// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Account _$AccountFromJson(Map<String, dynamic> json) => _Account(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  broker: Broker.fromJson(json['broker'] as Map<String, dynamic>),
  accountIdentifier: json['account_identifier'] as String?,
  accountType: json['account_type'] as String,
  currency: json['currency'] as String,
  isManual: json['is_manual'] as bool,
  syncEnabled: json['sync_enabled'] as bool,
  status: json['status'] as String,
  lastSyncAt: json['last_sync_at'] as String?,
  lastSyncError: json['last_sync_error'] as String?,
  latestSnapshot: json['latest_snapshot'] == null
      ? null
      : AccountSnapshot.fromJson(
          json['latest_snapshot'] as Map<String, dynamic>,
        ),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$AccountToJson(_Account instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'broker': instance.broker,
  'account_identifier': instance.accountIdentifier,
  'account_type': instance.accountType,
  'currency': instance.currency,
  'is_manual': instance.isManual,
  'sync_enabled': instance.syncEnabled,
  'status': instance.status,
  'last_sync_at': instance.lastSyncAt,
  'last_sync_error': instance.lastSyncError,
  'latest_snapshot': instance.latestSnapshot,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
