import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot.freezed.dart';
part 'snapshot.g.dart';

@freezed
abstract class AccountSnapshot with _$AccountSnapshot {
  const factory AccountSnapshot({
    required int id,
    required String balance,
    required String currency,
    @JsonKey(name: 'balance_base_currency') String? balanceBaseCurrency,
    @JsonKey(name: 'base_currency') String? baseCurrency,
    @JsonKey(name: 'snapshot_date') required String snapshotDate,
    @JsonKey(name: 'snapshot_source') String? snapshotSource,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _AccountSnapshot;

  factory AccountSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AccountSnapshotFromJson(json);
}

extension AccountSnapshotX on AccountSnapshot {
  double get balanceValue => double.tryParse(balance) ?? 0.0;

  double? get balanceBaseCurrencyValue =>
      balanceBaseCurrency != null ? double.tryParse(balanceBaseCurrency!) : null;

  DateTime get snapshotDateTime => DateTime.parse(snapshotDate);
}
