import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../providers/stale_sync_provider.dart';

/// One card per account that needs a code and has gone unsynced, coloured by
/// how overdue it is. Tapping a card starts that account's sync. Renders
/// nothing while every such account is fine.
class StaleSyncBanner extends ConsumerWidget {
  final Future<void> Function(Account account) onSync;
  final Set<int> syncingAccountIds;

  const StaleSyncBanner({
    super.key,
    required this.onSync,
    this.syncingAccountIds = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(staleSyncStatusesProvider);
    if (statuses.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          return _StaleSyncCard(
            status: status,
            syncing: syncingAccountIds.contains(status.account.id),
            onTap: () => onSync(status.account),
          );
        },
      ),
    );
  }
}

class _StaleSyncCard extends StatelessWidget {
  final StaleSyncStatus status;
  final bool syncing;
  final VoidCallback onTap;

  const _StaleSyncCard({
    required this.status,
    required this.syncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (background, foreground, icon) = switch (status.level) {
      StaleSyncLevel.notice => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          Icons.info_outline,
        ),
      StaleSyncLevel.warning => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          Icons.warning_amber_rounded,
        ),
      StaleSyncLevel.urgent => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Icons.error_outline,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: background,
        child: InkWell(
          onTap: syncing ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.title,
                        style: textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.detail,
                        style: textTheme.bodySmall?.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (syncing)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(Icons.sync, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
