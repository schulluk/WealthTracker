import 'package:flutter_test/flutter_test.dart';

import 'package:wealth_tracker/data/models/account.dart';
import 'package:wealth_tracker/data/models/broker.dart';
import 'package:wealth_tracker/data/models/snapshot.dart';
import 'package:wealth_tracker/presentation/providers/stale_sync_provider.dart';

final _now = DateTime(2026, 10, 19, 14, 0);

String _daysAgo(int days, {int hour = 12}) =>
    DateTime(_now.year, _now.month, _now.day - days, hour).toIso8601String();

Account _account({
  int id = 1,
  String name = 'Cashback Cards',
  bool interactive = true,
  bool syncEnabled = true,
  String? lastSyncAt,
  AccountSnapshot? snapshot,
  String? createdAt,
}) =>
    Account(
      id: id,
      name: name,
      broker: Broker(
        code: interactive ? 'swisscard' : 'ibkr',
        name: 'Broker',
        supportsAutoSync: !interactive,
        requiresInteractiveSync: interactive,
      ),
      accountType: 'credit_card',
      currency: 'CHF',
      isManual: false,
      syncEnabled: syncEnabled,
      status: 'active',
      lastSyncAt: lastSyncAt,
      latestSnapshot: snapshot,
      createdAt: createdAt,
    );

void main() {
  group('staleSyncStatusOf', () {
    test('ignores accounts that sync unattended', () {
      final account = _account(interactive: false, lastSyncAt: _daysAgo(40));
      expect(staleSyncStatusOf(account, _now), isNull);
    });

    test('ignores accounts whose sync is switched off', () {
      final account = _account(syncEnabled: false, lastSyncAt: _daysAgo(40));
      expect(staleSyncStatusOf(account, _now), isNull);
    });

    test('is quiet until the first step', () {
      expect(
          staleSyncStatusOf(_account(lastSyncAt: _daysAgo(20)), _now), isNull);
      final status = staleSyncStatusOf(_account(lastSyncAt: _daysAgo(21)), _now);
      expect(status?.level, StaleSyncLevel.notice);
      expect(status?.days, 21);
      expect(status?.title, 'Cashback Cards not synced for 21 days');
    });

    test('escalates at 25 and 28 days and stays urgent after', () {
      StaleSyncLevel? levelAfter(int days) =>
          staleSyncStatusOf(_account(lastSyncAt: _daysAgo(days)), _now)?.level;
      expect(levelAfter(24), StaleSyncLevel.notice);
      expect(levelAfter(25), StaleSyncLevel.warning);
      expect(levelAfter(27), StaleSyncLevel.warning);
      expect(levelAfter(28), StaleSyncLevel.urgent);
      expect(levelAfter(90), StaleSyncLevel.urgent);
    });

    test('counts calendar days, not full 24-hour spans', () {
      // Synced late in the evening 21 days ago, checked early today.
      final account = _account(lastSyncAt: _daysAgo(21, hour: 23));
      final morning = DateTime(_now.year, _now.month, _now.day, 8);
      expect(staleSyncStatusOf(account, morning)?.days, 21);
    });

    test('falls back to the newest snapshot, then to when it was added', () {
      final bySnapshot = _account(
        snapshot: AccountSnapshot(
          id: 1,
          balance: '-100',
          currency: 'CHF',
          snapshotDate: _daysAgo(30).substring(0, 10),
        ),
      );
      expect(staleSyncStatusOf(bySnapshot, _now)?.level, StaleSyncLevel.urgent);

      final byCreation = _account(createdAt: _daysAgo(22));
      expect(staleSyncStatusOf(byCreation, _now)?.days, 22);

      expect(staleSyncStatusOf(_account(), _now), isNull);
    });
  });

  group('staleSyncStatuses', () {
    test('lists the most overdue account first', () {
      final statuses = staleSyncStatuses([
        _account(id: 1, name: 'Card A', lastSyncAt: _daysAgo(22)),
        _account(id: 2, name: 'Fine', lastSyncAt: _daysAgo(3)),
        _account(id: 3, name: 'Card B', lastSyncAt: _daysAgo(30)),
      ], _now);
      expect(statuses.map((s) => s.account.name), ['Card B', 'Card A']);
    });
  });

  group('planStaleSyncAlerts', () {
    test('plans one notification per step at the reminder time', () {
      final alerts = planStaleSyncAlerts(
        [_account(lastSyncAt: _daysAgo(2))],
        now: _now,
        hour: 9,
        minute: 30,
      );
      expect(alerts.length, 3);
      expect(alerts.first.when, DateTime(2026, 10, 17 + 21, 9, 30));
      expect(alerts.last.when, DateTime(2026, 10, 17 + 28, 9, 30));
      expect(alerts.map((a) => a.payload).toSet(), {'stale_sync:1'});
      expect(alerts.first.body, contains('21 days'));
      expect(alerts.last.body, contains('28 days'));
    });

    test('leaves out steps already passed and accounts that sync unattended',
        () {
      final alerts = planStaleSyncAlerts(
        [
          _account(id: 1, lastSyncAt: _daysAgo(23)),
          _account(id: 2, interactive: false, lastSyncAt: _daysAgo(23)),
        ],
        now: _now,
        hour: 9,
        minute: 0,
      );
      expect(alerts.map((a) => a.payload).toSet(), {'stale_sync:1'});
      expect(alerts.map((a) => a.when.day), [21, 24]); // 25 and 28 days on
    });

    test('wording grows more insistent with every step', () {
      final messages = [
        for (final level in StaleSyncLevel.values)
          staleSyncMessage('Cashback Cards', level),
      ];
      expect(messages[0], contains('open the app'));
      expect(messages[1], contains('next few days'));
      expect(messages[2], contains('now'));
      for (final message in messages) {
        expect(message, startsWith('Cashback Cards has not synced for'));
      }
    });
  });
}
