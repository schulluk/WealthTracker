import 'package:freezed_annotation/freezed_annotation.dart';

part 'broker.freezed.dart';
part 'broker.g.dart';

@freezed
abstract class Broker with _$Broker {
  const factory Broker({
    required String code,
    required String name,
    @JsonKey(name: 'supports_auto_sync') @Default(false) bool supportsAutoSync,
  }) = _Broker;

  factory Broker.fromJson(Map<String, dynamic> json) => _$BrokerFromJson(json);
}
