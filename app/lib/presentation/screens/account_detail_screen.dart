import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/snapshot.dart';
import '../providers/accounts_provider.dart';
import '../providers/core_providers.dart';
import '../widgets/add_snapshot_dialog.dart';
import '../widgets/wealth_line_chart.dart';

class AccountDetailScreen extends ConsumerWidget {
  final int accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  Account? _findAccount(WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value;
    if (accounts == null) return null;
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountSnapshotsProvider(accountId));
    ref.invalidate(accountsProvider);
  }

  void _showAddSnapshotDialog(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) => AddSnapshotDialog(
        account: account,
        onSaved: () {
          Navigator.pop(context);
          _refresh(ref);
        },
      ),
    );
  }

  Future<void> _confirmDeleteSnapshot(
    BuildContext context,
    WidgetRef ref,
    AccountSnapshot snapshot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete snapshot?'),
        content: const Text(
          'This will remove this balance entry from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteSnapshot(snapshot.id);
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = _findAccount(ref);
    final history = ref.watch(accountHistoryProvider(accountId));
    final snapshots = ref.watch(accountSnapshotsProvider(accountId));
    final dateFormat = ref.watch(dateFormatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(account?.name ?? 'Account'),
      ),
      floatingActionButton: account != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSnapshotDialog(context, ref, account),
              icon: const Icon(Icons.add),
              label: const Text('Add Snapshot'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            // Header
            if (account != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.broker.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (account.latestSnapshot != null)
                        Text(
                          formatCurrency(
                            account.latestSnapshot!.balanceValue,
                            account.currency,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
              ),

            // Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: history.when(
                  data: (points) => WealthLineChart(
                    history: points,
                    currency: account?.currency ?? 'CHF',
                    showGranularitySelector: false,
                  ),
                  loading: () => const Card(
                    child: SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Failed to load history: $e',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Snapshots header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Snapshots',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (snapshots.value != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${snapshots.value!.length})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Snapshot list
            snapshots.when(
              data: (list) {
                if (list.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No snapshots yet')),
                    ),
                  );
                }
                final sorted = [...list]
                  ..sort((a, b) =>
                      b.snapshotDateTime.compareTo(a.snapshotDateTime));
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final snapshot = sorted[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              formatCurrency(
                                snapshot.balanceValue,
                                snapshot.currency,
                              ),
                            ),
                            subtitle: Text(
                              formatDate(snapshot.snapshotDateTime, dateFormat),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete snapshot',
                              onPressed: () => _confirmDeleteSnapshot(
                                context,
                                ref,
                                snapshot,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: sorted.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Failed to load snapshots: $e'),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}
