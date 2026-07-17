import 'package:freezed_annotation/freezed_annotation.dart';

import 'broker.dart';
import 'snapshot.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
abstract class Account with _$Account {
  const Account._();

  const factory Account({
    required int id,
    required String name,
    required Broker broker,
    @JsonKey(name: 'account_identifier') String? accountIdentifier,
    @JsonKey(name: 'account_type') required String accountType,
    required String currency,
    @JsonKey(name: 'is_manual') required bool isManual,
    @JsonKey(name: 'sync_enabled') required bool syncEnabled,
    required String status,
    @JsonKey(name: 'last_sync_at') String? lastSyncAt,
    @JsonKey(name: 'last_sync_error') String? lastSyncError,
    @JsonKey(name: 'latest_snapshot') AccountSnapshot? latestSnapshot,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  /// Whether this account requires manual snapshot entry.
  /// True if the account is manual, sync is disabled, or broker doesn't support auto-sync.
  bool get needsManualEntry =>
      isManual || !syncEnabled || !broker.supportsAutoSync;

  /// Whether this account is missing today's snapshot.
  bool isMissingTodaySnapshot() {
    if (latestSnapshot == null) return true;

    final today = DateTime.now();
    final snapshotDate = latestSnapshot!.snapshotDateTime;

    return today.year != snapshotDate.year ||
        today.month != snapshotDate.month ||
        today.day != snapshotDate.day;
  }
}
