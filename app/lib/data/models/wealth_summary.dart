import 'package:freezed_annotation/freezed_annotation.dart';

part 'wealth_summary.freezed.dart';
part 'wealth_summary.g.dart';

@freezed
abstract class WealthSummary with _$WealthSummary {
  const factory WealthSummary({
    @JsonKey(name: 'total_wealth') required double totalWealth,
    @JsonKey(name: 'base_currency') required String baseCurrency,
    @JsonKey(name: 'account_count') required int accountCount,
  }) = _WealthSummary;

  factory WealthSummary.fromJson(Map<String, dynamic> json) =>
      _$WealthSummaryFromJson(json);
}

@freezed
abstract class WealthHistoryPoint with _$WealthHistoryPoint {
  const factory WealthHistoryPoint({
    required String date,
    @JsonKey(name: 'total_wealth') required double totalWealth,
  }) = _WealthHistoryPoint;

  factory WealthHistoryPoint.fromJson(Map<String, dynamic> json) =>
      _$WealthHistoryPointFromJson(json);
}

extension WealthHistoryPointX on WealthHistoryPoint {
  DateTime get dateTime => DateTime.parse(date);
}
