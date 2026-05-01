import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/snapshot.dart';
import '../../data/models/wealth_summary.dart';
import '../../data/repositories/account_repository.dart';
import 'core_providers.dart';
import 'wealth_provider.dart';

/// Provider for the account repository.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AccountRepository(apiClient);
});

/// Provider for fetching all accounts.
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getAccounts();
});

/// Provider for raw snapshots of a single account.
final accountSnapshotsProvider =
    FutureProvider.family<List<AccountSnapshot>, int>((ref, accountId) async {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getSnapshots(accountId);
});

/// Provider for a single account's history points, filtered by the global
/// chart range. Uses the account's native currency balance.
final accountHistoryProvider =
    FutureProvider.family<List<WealthHistoryPoint>, int>((ref, accountId) async {
  final snapshots = await ref.watch(accountSnapshotsProvider(accountId).future);
  final days = ref.watch(chartRangeProvider);

  final cutoff = DateTime.now().subtract(Duration(days: days));
  final points = snapshots
      .where((s) => !s.snapshotDateTime.isBefore(cutoff))
      .map((s) => WealthHistoryPoint(
            date: s.snapshotDate,
            totalWealth: s.balanceValue,
          ))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return points;
});

/// Provider for accounts that need manual snapshot entry today.
final accountsNeedingSnapshotsProvider =
    FutureProvider<List<Account>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);

  return accounts.where((account) {
    // Only accounts that need manual entry (manual or sync disabled)
    if (!account.needsManualEntry) return false;

    // Check if missing today's snapshot
    return account.isMissingTodaySnapshot();
  }).toList();
});
