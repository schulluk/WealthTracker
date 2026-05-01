import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/snapshot.dart';
import '../providers/core_providers.dart';
import 'add_snapshot_dialog.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final String baseCurrency;
  final VoidCallback? onSnapshotAdded;
  final Future<void> Function()? onSync;
  final bool isSyncing;

  const AccountCard({
    super.key,
    required this.account,
    required this.baseCurrency,
    this.onSnapshotAdded,
    this.onSync,
    this.isSyncing = false,
  });

  void _showAddSnapshotDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddSnapshotDialog(
        account: account,
        onSaved: () {
          Navigator.pop(context);
          onSnapshotAdded?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = ref.watch(dateFormatProvider);
    final snapshot = account.latestSnapshot;
    final balance = snapshot?.balanceValue ?? 0;
    final balanceInBase = snapshot?.balanceBaseCurrencyValue ?? balance;

    return Card(
      child: InkWell(
        onTap: () => context.push('/accounts/${account.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Account info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.broker.name,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Balance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(balance, account.currency),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (account.currency != baseCurrency)
                        Text(
                          formatCurrency(balanceInBase, baseCurrency),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Buttons stacked vertically: Add on top, Sync below
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Add button
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddSnapshotDialog(context),
                        tooltip: 'Add Snapshot',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Sync button (only for auto-sync accounts)
                      if (_canSync)
                        IconButton(
                          icon: isSyncing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          onPressed: isSyncing ? null : onSync,
                          tooltip: 'Sync Account',
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
              // Updated date aligned with account name (8px dot + 12px spacing)
              if (snapshot != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Updated ${_getSyncDateText(dateFormat)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      Text(
                        'Balance from ${formatDateSmart(snapshot.snapshotDateTime, dateFormat)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get the sync date text for "Updated" line.
  /// For auto-sync accounts, shows lastSyncAt. For manual, shows snapshot date.
  String _getSyncDateText(String dateFormat) {
    final lastSyncAt = account.lastSyncAt;
    final snapshot = account.latestSnapshot;

    // For auto-sync accounts, prefer lastSyncAt
    if (lastSyncAt != null && _canSync) {
      final syncDate = DateTime.tryParse(lastSyncAt);
      if (syncDate != null) {
        return formatDateSmart(syncDate, dateFormat);
      }
    }

    // Fallback to snapshot date
    if (snapshot != null) {
      return formatDateSmart(snapshot.snapshotDateTime, dateFormat);
    }

    return 'never';
  }

  /// Get the DateTime to use for staleness calculation.
  DateTime? _getUpdateDateTime() {
    final lastSyncAt = account.lastSyncAt;
    final snapshot = account.latestSnapshot;

    // For auto-sync accounts, prefer lastSyncAt
    if (lastSyncAt != null && _canSync) {
      final syncDate = DateTime.tryParse(lastSyncAt);
      if (syncDate != null) return syncDate;
    }

    // Fallback to snapshot date
    return snapshot?.snapshotDateTime;
  }

  Color _getStatusColor(BuildContext context) {
    final updateDateTime = _getUpdateDateTime();
    if (updateDateTime == null) {
      return Theme.of(context).colorScheme.error;
    }
    final daysSinceUpdate = DateTime.now().difference(updateDateTime).inDays;
    if (daysSinceUpdate <= 1) {
      return Colors.green;
    } else if (daysSinceUpdate <= 7) {
      return Colors.orange;
    } else {
      return Theme.of(context).colorScheme.error;
    }
  }

  /// Whether this account can be manually synced from the app.
  /// Only accounts with sync enabled AND broker supports auto-sync.
  bool get _canSync => account.syncEnabled && account.broker.supportsAutoSync;
}
