import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/account.dart';
import '../../data/models/snapshot.dart';
import '../../services/notification_service.dart';
import 'accounts_provider.dart';
import 'core_providers.dart';

/// Brokers that stop for a one-time code (an SMS, a TAN) are skipped by
/// "Sync all" and by the sync on app open: a bulk run would only trigger
/// codes nobody is waiting for. Nothing else reminds the user to sync them by
/// hand, so once such an account has gone three weeks without a sync the
/// start screen says so, and a notification does the same even when the app
/// stays closed, in three steps of growing urgency.

/// Payload prefix of the stale-sync notifications; the account id follows.
const staleSyncPayloadPrefix = 'stale_sync:';

/// How overdue an account that is left out of unattended syncs has become.
enum StaleSyncLevel {
  notice(AppConfig.staleSyncNoticeDays),
  warning(AppConfig.staleSyncWarningDays),
  urgent(AppConfig.staleSyncUrgentDays);

  const StaleSyncLevel(this.days);

  /// Days since the last sync at which this level starts.
  final int days;

  /// The level reached after [days] without a sync, or null while fine.
  static StaleSyncLevel? forDays(int days) {
    StaleSyncLevel? reached;
    for (final level in values) {
      if (days >= level.days) reached = level;
    }
    return reached;
  }
}

/// One overdue account and how overdue it is.
class StaleSyncStatus {
  final Account account;
  final int days;
  final StaleSyncLevel level;

  const StaleSyncStatus({
    required this.account,
    required this.days,
    required this.level,
  });

  /// Headline for the start screen.
  String get title => '${account.name} not synced for $days days';

  /// What to do about it, sharper with every level.
  String get detail => staleSyncAdvice(level);
}

/// The nudge for [level], shared by the banner and the notification body.
String staleSyncAdvice(StaleSyncLevel level) {
  switch (level) {
    case StaleSyncLevel.notice:
      return 'It needs a code, so automatic syncs skip it. Tap to sync.';
    case StaleSyncLevel.warning:
      return 'Sync it in the next few days to keep its history complete.';
    case StaleSyncLevel.urgent:
      return 'Sync it now, or its history will have a gap.';
  }
}

/// Body of the notification sent when [name] reaches [level].
String staleSyncMessage(String name, StaleSyncLevel level) {
  final advice = level == StaleSyncLevel.notice
      ? 'It needs a code, so open the app and sync it.'
      : staleSyncAdvice(level);
  return '$name has not synced for ${level.days} days. $advice';
}

/// Whether this account is left out of unattended runs, and so can go stale
/// without anyone noticing.
bool needsAttendedSync(Account account) =>
    account.canSync && account.broker.requiresInteractiveSync;

/// When the account was last brought up to date: the last sync, else the
/// newest snapshot, else the day it was added (an account never synced counts
/// from then). Null when none of these is known.
DateTime? lastUpdateOf(Account account) {
  final lastSync = account.lastSyncAt;
  if (lastSync != null) {
    final parsed = DateTime.tryParse(lastSync);
    if (parsed != null) return parsed.toLocal();
  }
  final snapshot = account.latestSnapshot;
  if (snapshot != null) return snapshot.snapshotDateTime;
  final created = account.createdAt;
  if (created != null) {
    final parsed = DateTime.tryParse(created);
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

/// Whole calendar days from [from] to [now], so a sync late in the evening
/// and a check early next morning count as one day, not zero.
int calendarDaysBetween(DateTime from, DateTime now) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(now.year, now.month, now.day);
  return end.difference(start).inDays;
}

/// How overdue [account] is, or null when it syncs unattended, is fine, or
/// its last update is unknown.
StaleSyncStatus? staleSyncStatusOf(Account account, DateTime now) {
  if (!needsAttendedSync(account)) return null;
  final last = lastUpdateOf(account);
  if (last == null) return null;
  final days = calendarDaysBetween(last, now);
  final level = StaleSyncLevel.forDays(days);
  if (level == null) return null;
  return StaleSyncStatus(account: account, days: days, level: level);
}

/// The overdue accounts among [accounts], most overdue first.
List<StaleSyncStatus> staleSyncStatuses(List<Account> accounts, DateTime now) {
  final statuses = <StaleSyncStatus>[];
  for (final account in accounts) {
    final status = staleSyncStatusOf(account, now);
    if (status != null) statuses.add(status);
  }
  statuses.sort((a, b) => b.days.compareTo(a.days));
  return statuses;
}

/// The notifications to schedule: for every account that needs a code, one
/// per level on the day it is reached, at the reminder time. Dates already
/// past are left out — the start screen covers them while the app is open.
List<LocalAlert> planStaleSyncAlerts(
  List<Account> accounts, {
  required DateTime now,
  required int hour,
  required int minute,
}) {
  final alerts = <LocalAlert>[];
  for (final account in accounts.where(needsAttendedSync)) {
    final last = lastUpdateOf(account);
    if (last == null) continue;
    for (final level in StaleSyncLevel.values) {
      final when =
          DateTime(last.year, last.month, last.day + level.days, hour, minute);
      if (!when.isAfter(now)) continue;
      alerts.add(LocalAlert(
        when: when,
        body: staleSyncMessage(account.name, level),
        payload: '$staleSyncPayloadPrefix${account.id}',
      ));
    }
  }
  alerts.sort((a, b) => a.when.compareTo(b.when));
  return alerts;
}

/// Overdue accounts for the start screen, most overdue first.
final staleSyncStatusesProvider = Provider<List<StaleSyncStatus>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  return staleSyncStatuses(accounts, DateTime.now());
});

/// Keeps the scheduled stale-sync notifications in step with the accounts.
final staleSyncAlertsProvider = Provider<StaleSyncAlerts>(StaleSyncAlerts.new);

class StaleSyncAlerts {
  final Ref _ref;

  /// What the platform currently holds, so an unchanged plan is not re-sent
  /// on every refresh of the account list.
  String? _scheduled;

  StaleSyncAlerts(this._ref);

  /// Re-plan from [accounts] and hand the result to the platform when it
  /// differs from what is scheduled. Needs notification permission, which is
  /// never asked for here — only in Settings.
  Future<void> reschedule(List<Account> accounts) async {
    final service = _ref.read(notificationServiceProvider);
    final wanted = await service.isStaleSyncAlertsEnabled() &&
        await service.hasNotificationPermission();
    final alerts = wanted
        ? planStaleSyncAlerts(
            accounts,
            now: DateTime.now(),
            hour: await service.getSyncReminderHour(),
            minute: await service.getSyncReminderMinute(),
          )
        : const <LocalAlert>[];
    final plan = alerts
        .map((a) => '${a.payload}@${a.when.toIso8601String()}')
        .join(';');
    if (plan == _scheduled) return;
    await service.scheduleStaleSyncAlerts(alerts);
    _scheduled = plan;
  }
}
