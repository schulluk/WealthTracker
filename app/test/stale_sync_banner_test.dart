import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wealth_tracker/data/models/account.dart';
import 'package:wealth_tracker/data/models/broker.dart';
import 'package:wealth_tracker/presentation/providers/stale_sync_provider.dart';
import 'package:wealth_tracker/presentation/widgets/stale_sync_banner.dart';

Account _account(int id, String name) => Account(
      id: id,
      name: name,
      broker: const Broker(
        code: 'swisscard',
        name: 'Swisscard',
        requiresInteractiveSync: true,
      ),
      accountType: 'credit_card',
      currency: 'CHF',
      isManual: false,
      syncEnabled: true,
      status: 'active',
    );

Widget _harness(
  List<StaleSyncStatus> statuses, {
  required Future<void> Function(Account) onSync,
  Set<int> syncing = const {},
}) =>
    ProviderScope(
      overrides: [staleSyncStatusesProvider.overrideWithValue(statuses)],
      child: MaterialApp(
        home: Scaffold(
          body: CustomScrollView(slivers: [
            StaleSyncBanner(onSync: onSync, syncingAccountIds: syncing),
          ]),
        ),
      ),
    );

void main() {
  group('StaleSyncBanner', () {
    testWidgets('renders nothing while every account is fine', (tester) async {
      await tester.pumpWidget(_harness(const [], onSync: (_) async {}));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows one card per overdue account with its advice',
        (tester) async {
      await tester.pumpWidget(_harness([
        StaleSyncStatus(
          account: _account(1, 'Card A'),
          days: 30,
          level: StaleSyncLevel.urgent,
        ),
        StaleSyncStatus(
          account: _account(2, 'Card B'),
          days: 21,
          level: StaleSyncLevel.notice,
        ),
      ], onSync: (_) async {}));

      expect(find.text('Card A not synced for 30 days'), findsOneWidget);
      expect(find.text(staleSyncAdvice(StaleSyncLevel.urgent)), findsOneWidget);
      expect(find.text('Card B not synced for 21 days'), findsOneWidget);
      expect(find.text(staleSyncAdvice(StaleSyncLevel.notice)), findsOneWidget);
    });

    testWidgets('tapping a card starts that account\'s sync', (tester) async {
      Account? synced;
      await tester.pumpWidget(_harness([
        StaleSyncStatus(
          account: _account(7, 'Card A'),
          days: 25,
          level: StaleSyncLevel.warning,
        ),
      ], onSync: (account) async => synced = account));

      await tester.tap(find.text('Card A not synced for 25 days'));
      await tester.pump();

      expect(synced?.id, 7);
    });

    testWidgets('a card whose account is syncing spins and ignores taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(
        [
          StaleSyncStatus(
            account: _account(7, 'Card A'),
            days: 25,
            level: StaleSyncLevel.warning,
          ),
        ],
        onSync: (_) async => taps++,
        syncing: const {7},
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Card A not synced for 25 days'));
      await tester.pump();
      expect(taps, 0);
    });
  });
}
