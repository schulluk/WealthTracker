// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broker.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Broker _$BrokerFromJson(Map<String, dynamic> json) => _Broker(
  code: json['code'] as String,
  name: json['name'] as String,
  supportsAutoSync: json['supports_auto_sync'] as bool? ?? false,
);

Map<String, dynamic> _$BrokerToJson(_Broker instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'supports_auto_sync': instance.supportsAutoSync,
};
