// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wealth_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WealthSummary _$WealthSummaryFromJson(Map<String, dynamic> json) =>
    _WealthSummary(
      totalWealth: (json['total_wealth'] as num).toDouble(),
      baseCurrency: json['base_currency'] as String,
      accountCount: (json['account_count'] as num).toInt(),
    );

Map<String, dynamic> _$WealthSummaryToJson(_WealthSummary instance) =>
    <String, dynamic>{
      'total_wealth': instance.totalWealth,
      'base_currency': instance.baseCurrency,
      'account_count': instance.accountCount,
    };

_WealthHistoryPoint _$WealthHistoryPointFromJson(Map<String, dynamic> json) =>
    _WealthHistoryPoint(
      date: json['date'] as String,
      totalWealth: (json['total_wealth'] as num).toDouble(),
    );

Map<String, dynamic> _$WealthHistoryPointToJson(_WealthHistoryPoint instance) =>
    <String, dynamic>{
      'date': instance.date,
      'total_wealth': instance.totalWealth,
    };
