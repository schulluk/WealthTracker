// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileImpl _$$ProfileImplFromJson(Map<String, dynamic> json) =>
    _$ProfileImpl(
      baseCurrency: json['base_currency'] as String,
      autoSyncEnabled: json['auto_sync_enabled'] as bool,
      sendWeeklyReport: json['send_weekly_report'] as bool,
      defaultChartRange: (json['default_chart_range'] as num).toInt(),
      defaultChartGranularity: json['default_chart_granularity'] as String,
      pushNotificationsEnabled:
          json['push_notifications_enabled'] as bool? ?? true,
      pushWeeklyReport: json['push_weekly_report'] as bool? ?? false,
      syncOnAppOpen: json['sync_on_app_open'] as bool? ?? false,
      encryptionMigrated: json['encryption_migrated'] as bool? ?? false,
    );

Map<String, dynamic> _$$ProfileImplToJson(_$ProfileImpl instance) =>
    <String, dynamic>{
      'base_currency': instance.baseCurrency,
      'auto_sync_enabled': instance.autoSyncEnabled,
      'send_weekly_report': instance.sendWeeklyReport,
      'default_chart_range': instance.defaultChartRange,
      'default_chart_granularity': instance.defaultChartGranularity,
      'push_notifications_enabled': instance.pushNotificationsEnabled,
      'push_weekly_report': instance.pushWeeklyReport,
      'sync_on_app_open': instance.syncOnAppOpen,
      'encryption_migrated': instance.encryptionMigrated,
    };
