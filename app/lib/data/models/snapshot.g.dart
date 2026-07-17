// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountSnapshot _$AccountSnapshotFromJson(Map<String, dynamic> json) =>
    _AccountSnapshot(
      id: (json['id'] as num).toInt(),
      balance: json['balance'] as String,
      currency: json['currency'] as String,
      balanceBaseCurrency: json['balance_base_currency'] as String?,
      baseCurrency: json['base_currency'] as String?,
      snapshotDate: json['snapshot_date'] as String,
      snapshotSource: json['snapshot_source'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$AccountSnapshotToJson(_AccountSnapshot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'balance': instance.balance,
      'currency': instance.currency,
      'balance_base_currency': instance.balanceBaseCurrency,
      'base_currency': instance.baseCurrency,
      'snapshot_date': instance.snapshotDate,
      'snapshot_source': instance.snapshotSource,
      'created_at': instance.createdAt,
    };
