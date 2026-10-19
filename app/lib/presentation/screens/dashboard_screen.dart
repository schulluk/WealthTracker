import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../data/repositories/account_repository.dart';
import '../../services/ms_relay/relay_service.dart';
import 'dart:async';

import '../../main.dart' show initialNotificationResponse, notificationTapStream;
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stale_sync_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/wealth_provider.dart';
import '../widgets/account_card.dart';
import '../widgets/holdings_card.dart';
import '../widgets/quick_snapshot_sheet.dart';
import '../widgets/stale_sync_banner.dart';
import '../widgets/sync_progress_dialog.dart';
import '../widgets/two_factor_prompt.dart';
import '../widgets/wealth_line_chart.dart';
import '../widgets/wealth_summary_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _checkedQuickSnapshot = false;
  final Set<int> _syncingAccounts = {};
  StreamSubscription<String>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationSub = notificationTapStream.stream.listen(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQuickSnapshotPrompt();
      _initializeSyncReminders();
      _initStartupSync();
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onNotificationTap(String payload) {
    if (!mounted) return;
    if (payload == 'sync_reminder') {
      debugPrint('Sync reminder notification tapped while app running, triggering sync');
      _syncAllAccounts();
    } else if (payload.startsWith(staleSyncPayloadPrefix)) {
      _syncAccountById(_accountIdOf(payload));
    }
  }

  /// The account a stale-sync notification is about.
  int? _accountIdOf(String payload) =>
      int.tryParse(payload.substring(staleSyncPayloadPrefix.length));

  /// Start one account's sync, e.g. from the notification that it is overdue.
  Future<void> _syncAccountById(int? id) async {
    if (id == null) return;
    final accounts = await ref.read(accountsProvider.future);
    final account = accounts.where((a) => a.id == id).firstOrNull;
    if (account != null && mounted) await _syncAccount(account);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check if we should sync
      _checkSyncOnAppOpen();
    }
  }

  Future<void> _initializeSyncReminders() async {
    try {
      await ref.read(syncSettingsProvider).initializeSyncReminders();
    } catch (e) {
      debugPrint('Failed to initialize sync reminders: $e');
    }
  }

  /// Run notification-launch sync first, then sync-on-app-open (if not already syncing).
  Future<void> _initStartupSync() async {
    bool syncedFromNotification = false;

    // 1. Check if app was launched from a sync reminder notification
    final payload = initialNotificationResponse?.payload;
    if (payload == 'sync_reminder') {
      debugPrint('App launched from sync reminder notification, triggering sync');
      initialNotificationResponse = null;
      syncedFromNotification = true;

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _syncAllAccounts();
      }
    } else if (payload != null && payload.startsWith(staleSyncPayloadPrefix)) {
      // Launched from "X has not synced for N days": sync that account; the
      // sync on app open may still follow for the rest.
      debugPrint('App launched from stale-sync notification: $payload');
      initialNotificationResponse = null;

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _syncAccountById(_accountIdOf(payload));
      }
    }

    // 2. Check sync-on-app-open (skip if we already synced from notification)
    if (!syncedFromNotification && mounted) {
      try {
        await ref.read(syncAllProvider.notifier).trySyncOnAppOpen();
      } catch (e) {
        debugPrint('Auto-sync on app open failed: $e');
      }
    }
  }

  Future<void> _checkSyncOnAppOpen() async {
    if (!mounted) return;

    try {
      await ref.read(syncAllProvider.notifier).trySyncOnAppOpen();
    } catch (e) {
      debugPrint('Auto-sync on app open failed: $e');
    }
  }

  Future<void> _checkQuickSnapshotPrompt() async {
    if (_checkedQuickSnapshot) return;
    _checkedQuickSnapshot = true;

    final accountsNeeding =
        await ref.read(accountsNeedingSnapshotsProvider.future);

    if (accountsNeeding.isNotEmpty && mounted) {
      _showQuickSnapshotSheet(accountsNeeding);
    }
  }

  void _showQuickSnapshotSheet(List accounts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => QuickSnapshotSheet(
        accounts: accounts.cast(),
        onDismiss: () => Navigator.pop(context),
        onSnapshotsAdded: () {
          Navigator.pop(context);
          _refresh();
        },
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(wealthSummaryProvider);
    ref.invalidate(wealthHistoryProvider);
    ref.invalidate(wealthHoldingsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(accountsNeedingSnapshotsProvider);
  }

  Future<void> _syncAccount(Account account) async {
    if (_syncingAccounts.contains(account.id)) return;

    setState(() => _syncingAccounts.add(account.id));
    _showSyncHint();

    try {
      final repo = ref.read(accountRepositoryProvider);
      final relay = ref.read(relayServiceProvider);
      await relay.withRelay(() async {
        final startResult = await repo.syncAccount(account.id);
        final taskId = startResult['task_id'] as String?;

        if (taskId != null) {
          final outcome = await _pollSyncTask(repo, taskId);
          await _refresh();
          if (outcome == null) return;
          // Brokers that cannot sync unattended (Swisscard sends an SMS,
          // some FinTS banks a TAN) stop here and wait for the code.
          if (outcome['status'] == 'pending_auth') {
            await _askForAuthCode(repo, account, outcome);
            return;
          }
          if (outcome['status'] == 'error') {
            if (mounted) {
              _showSyncErrorsDialog([
                {
                  'name': account.name,
                  'error': outcome['error'] ?? 'Sync failed',
                }
              ]);
            }
            return;
          }
          if (mounted) {
            final message = outcome['message'] as String?;
            if (message != null) _showSuccessSnackBar(message);
          }
        }
      }, active: accountNeedsRelay(account));
    } catch (e) {
      if (mounted) {
        _showSyncErrorsDialog([
          {'name': account.name, 'error': e.toString()}
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _syncingAccounts.remove(account.id));
      }
    }
  }

  /// Ask for the broker's one-time code and finish the sync with it.
  Future<void> _askForAuthCode(
    AccountRepository repo,
    Account account,
    Map<String, dynamic> pending,
  ) async {
    if (!mounted) return;
    final challenge = pending['challenge'];
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TwoFactorPrompt(
        accountName: account.name,
        twoFaType: pending['two_fa_type'] as String? ?? 'sms',
        challenge: challenge is Map ? challenge['message'] as String? : null,
        onSubmit: (code) async {
          try {
            final result = await repo.completeAccountAuth(account.id, code);
            final error = result['error'];
            return error is String ? error : null;
          } catch (e) {
            return '$e';
          }
        },
      ),
    );
    await _refresh();
    if (done == true && mounted) {
      _showSuccessSnackBar('${account.name} synced');
    }
  }

  /// Trigger a sync-all run via the shared provider. Progress and results
  /// are surfaced through the [syncAllProvider] listener in [build].
  Future<void> _syncAllAccounts() {
    return ref.read(syncAllProvider.notifier).syncAll();
  }

  /// Show the outcome of a completed sync-all run (manual or automatic).
  void _onSyncAllCompleted(SyncAllResult? result) {
    if (!mounted || result == null) return;

    if (result.errors.isNotEmpty) {
      _showSyncErrorsDialog(result.errors, syncedCount: result.syncedCount);
    } else if (result.message != null) {
      _showSuccessSnackBar(result.message!);
    } else if (result.syncedCount > 0) {
      _showSuccessSnackBar(
          'Synced ${result.syncedCount} account${result.syncedCount == 1 ? '' : 's'}');
    } else {
      _showSuccessSnackBar('All accounts up to date');
    }
  }

  /// Poll a sync task until it completes or fails, and return what the sync
  /// itself reported — the task envelope only says whether the worker ran.
  Future<Map<String, dynamic>?> _pollSyncTask(
    AccountRepository repo,
    String taskId,
  ) async {
    const pollInterval = Duration(seconds: 2);
    const maxPolls = 180; // 6 minutes max

    for (var i = 0; i < maxPolls; i++) {
      await Future.delayed(pollInterval);
      if (!mounted) return null;

      try {
        final status = await repo.getSyncTaskStatus(taskId);
        final taskStatus = status['status'] as String?;

        if (taskStatus == 'completed') {
          final result = status['result'];
          return result is Map
              ? result.cast<String, dynamic>()
              : {'status': 'success'};
        }
        if (taskStatus == 'failed') {
          return {
            'status': 'error',
            'error': status['error'] ?? 'Sync failed',
          };
        }
      } catch (_) {
        // Status endpoint failed — keep polling
      }
    }
    return null;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSyncErrorsDialog(List errors, {int syncedCount = 0}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Sync Results'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Text(
                syncedCount > 0
                    ? '$syncedCount account${syncedCount == 1 ? '' : 's'} synced successfully, ${errors.length} had errors:'
                    : '${errors.length} account${errors.length == 1 ? '' : 's'} had errors:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // Error list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final error = errors[index] as Map<String, dynamic>;
                    final name = error['name'] as String? ?? 'Unknown Account';
                    final message = error['error'] as String? ?? 'Unknown error';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSyncHint() {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.smartphone, color: colorScheme.onInverseSurface, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Check your banking app for approval if required',
                style: TextStyle(color: colorScheme.onInverseSurface),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.inverseSurface,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Check if any account supports auto-sync.
  bool _hasAutoSyncAccounts(List<Account> accounts) {
    return accounts
        .any((a) => a.syncEnabled && a.broker.supportsAutoSync);
  }

  @override
  Widget build(BuildContext context) {
    final wealthSummary = ref.watch(wealthSummaryProvider);
    final wealthHistory = ref.watch(wealthHistoryProvider);
    final accounts = ref.watch(accountsProvider);
    final authState = ref.watch(authStateProvider);
    final syncingAll = ref.watch(syncAllProvider.select((s) => s.isSyncing));

    // Surface sync-all progress and results regardless of how the sync was
    // triggered (button, auto-sync on app open, notification tap).
    ref.listen<SyncAllState>(syncAllProvider, (previous, next) {
      final wasSyncing = previous?.isSyncing ?? false;
      if (!wasSyncing && next.isSyncing) {
        _showSyncHint();
      } else if (wasSyncing && !next.isSyncing) {
        _onSyncAllCompleted(next.lastResult);
      }
    });

    // Keep the "not synced for N days" notifications in step with the
    // accounts: every successful sync moves its account's dates forward.
    ref.listen<AsyncValue<List<Account>>>(accountsProvider, (previous, next) {
      if (next is AsyncData<List<Account>>) {
        unawaited(ref.read(staleSyncAlertsProvider).reschedule(next.value));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wealth Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Spending',
            onPressed: () => context.push('/spending'),
          ),
          IconButton(
            icon: const Icon(Icons.query_stats),
            tooltip: 'Simulation',
            onPressed: () => context.push('/simulation'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: syncingAll
            ? const PreferredSize(
                preferredSize: Size.fromHeight(_SyncStatusBar.height),
                child: _SyncStatusBar(),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: authState.whenOrNull(
                  data: (user) => Text(
                    'Hello, ${user?.firstName?.isNotEmpty == true ? user!.firstName : (user?.username ?? 'there')}!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),

            // Wealth Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: wealthSummary.when(
                  data: (summary) => WealthSummaryCard(summary: summary),
                  loading: () => const _LoadingCard(height: 100),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
              ),
            ),

            // Chart
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: wealthHistory.when(
                  data: (history) => WealthLineChart(
                    history: history,
                    currency:
                        wealthSummary.value?.baseCurrency ?? 'CHF',
                  ),
                  loading: () => const _LoadingCard(height: 250),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
              ),
            ),

            // Per-asset holdings (renders nothing until a broker reports them)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: HoldingsCard(),
              ),
            ),

            // Quick Snapshot Banner
            _QuickSnapshotBanner(
              onTap: () async {
                final accountsNeeding =
                    await ref.read(accountsNeedingSnapshotsProvider.future);
                if (accountsNeeding.isNotEmpty && mounted) {
                  _showQuickSnapshotSheet(accountsNeeding);
                }
              },
            ),

            // Accounts that need a code and have gone unsynced
            StaleSyncBanner(
              onSync: _syncAccount,
              syncingAccountIds: _syncingAccounts,
            ),

            // Accounts Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Accounts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (accounts.value != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${accounts.value!.length})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const Spacer(),
                    if (accounts.value != null &&
                        _hasAutoSyncAccounts(accounts.value!))
                      TextButton.icon(
                        onPressed: syncingAll ? null : _syncAllAccounts,
                        icon: syncingAll
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: const Text('Sync All'),
                      ),
                  ],
                ),
              ),
            ),

            // Accounts List
            accounts.when(
              data: (accountList) {
                if (accountList.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No accounts yet'),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final account = accountList[index];
                        final canSync = account.canSync;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AccountCard(
                            account: account,
                            baseCurrency:
                                wealthSummary.value?.baseCurrency ??
                                    'CHF',
                            onSnapshotAdded: _refresh,
                            onSync: canSync
                                ? () => _syncAccount(account)
                                : null,
                            isSyncing: _syncingAccounts.contains(account.id),
                          ),
                        );
                      },
                      childCount: accountList.length,
                    ),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(
                      3,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: _LoadingCard(height: 80),
                      ),
                    ),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorCard(message: e.toString()),
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim bar under the app bar shown while a sync-all run is in progress.
/// Stays visible while scrolling, unlike the button spinner in the list.
/// Tapping it opens the per-account breakdown of the run.
class _SyncStatusBar extends ConsumerWidget {
  static const double height = 32;

  const _SyncStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = ref.watch(syncAllProvider.select((s) => s.progress));
    final done = progress.where((a) => !a.isPending).length;
    final label = progress.isEmpty
        ? 'Syncing accounts…'
        : 'Syncing accounts… $done of ${progress.length}';

    return Material(
      color: colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => SyncProgressDialog.show(context),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;

  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSnapshotBanner extends ConsumerWidget {
  final VoidCallback onTap;

  const _QuickSnapshotBanner({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsNeeding = ref.watch(accountsNeedingSnapshotsProvider);

    return accountsNeeding.when(
      data: (accounts) {
        if (accounts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${accounts.length} account${accounts.length == 1 ? '' : 's'} need${accounts.length == 1 ? 's' : ''} a balance update',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
