import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts_provider.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

/// State for sync-all operations.
class SyncAllState {
  final bool isSyncing;
  final String? error;
  final DateTime? lastSyncTime;
  final int? successCount;
  final int? failureCount;

  const SyncAllState({
    this.isSyncing = false,
    this.error,
    this.lastSyncTime,
    this.successCount,
    this.failureCount,
  });

  SyncAllState copyWith({
    bool? isSyncing,
    String? error,
    DateTime? lastSyncTime,
    int? successCount,
    int? failureCount,
  }) {
    return SyncAllState(
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}

/// Provider for sync-all operations with notification tracking.
final syncAllProvider =
    NotifierProvider<SyncAllNotifier, SyncAllState>(SyncAllNotifier.new);

class SyncAllNotifier extends Notifier<SyncAllState> {
  @override
  SyncAllState build() {
    _loadLastSyncTime();
    return const SyncAllState();
  }

  Future<void> _loadLastSyncTime() async {
    final notificationService = ref.read(notificationServiceProvider);
    final lastSync = await notificationService.getLastSyncAll();
    if (lastSync != null) {
      state = state.copyWith(lastSyncTime: lastSync);
    }
  }

  /// Sync all accounts.
  ///
  /// Records the sync timestamp for notification suppression.
  Future<void> syncAll() async {
    if (state.isSyncing) return;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      final repository = ref.read(accountRepositoryProvider);
      final notificationService = ref.read(notificationServiceProvider);

      final result = await repository.syncAllAccounts();

      // Extract results
      final results = result['results'] as List<dynamic>?;
      int successCount = 0;
      int failureCount = 0;

      if (results != null) {
        for (final r in results) {
          if (r['status'] == 'success') {
            successCount++;
          } else {
            failureCount++;
          }
        }
      }

      // Record sync timestamp
      await notificationService.recordSyncAll();

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        successCount: successCount,
        failureCount: failureCount,
      );

      // Refresh accounts data
      ref.invalidate(accountsProvider);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  /// Check if sync should run based on suppression threshold.
  Future<bool> shouldSync() async {
    final notificationService = ref.read(notificationServiceProvider);
    return notificationService.shouldSync();
  }

  /// Try to sync on app open if enabled and not recently synced.
  Future<void> trySyncOnAppOpen() async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null || !profile.syncOnAppOpen) return;

    final shouldRun = await shouldSync();
    if (!shouldRun) {
      debugPrint('Skipping auto-sync: synced recently');
      return;
    }

    debugPrint('Auto-syncing on app open');
    await syncAll();
  }
}

/// Provider to update sync settings.
final syncSettingsProvider = Provider((ref) => SyncSettingsManager(ref));

class SyncSettingsManager {
  final Ref _ref;

  SyncSettingsManager(this._ref);

  /// Update sync-on-app-open setting (stored on server).
  Future<void> updateSyncOnAppOpen(bool value) async {
    final repository = _ref.read(profileRepositoryProvider);
    await repository.updateProfile(syncOnAppOpen: value);
    _ref.invalidate(profileProvider);
  }

  /// Update sync reminder settings (stored locally).
  Future<void> updateSyncReminder({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    final notificationService = _ref.read(notificationServiceProvider);

    if (enabled != null) {
      await notificationService.setSyncReminderEnabled(enabled);
    }
    if (hour != null || minute != null) {
      final currentHour = hour ?? await notificationService.getSyncReminderHour();
      final currentMinute = minute ?? await notificationService.getSyncReminderMinute();
      await notificationService.setSyncReminderTime(currentHour, currentMinute);
    }

    // Schedule or cancel the notification
    final isEnabled = enabled ?? await notificationService.isSyncReminderEnabled();
    if (isEnabled) {
      final h = hour ?? await notificationService.getSyncReminderHour();
      final m = minute ?? await notificationService.getSyncReminderMinute();
      await notificationService.scheduleSyncReminder(hour: h, minute: m);
    } else {
      await notificationService.cancelSyncReminder();
    }
  }

  /// Initialize sync reminders from local settings.
  ///
  /// Only schedules the reminder if permissions are already granted.
  /// Does NOT prompt for permissions - that only happens when the user
  /// explicitly enables the reminder in settings.
  Future<void> initializeSyncReminders() async {
    final notificationService = _ref.read(notificationServiceProvider);
    await notificationService.initialize();

    final enabled = await notificationService.isSyncReminderEnabled();
    if (enabled) {
      final hasPermission =
          await notificationService.hasNotificationPermission();
      if (hasPermission) {
        final hour = await notificationService.getSyncReminderHour();
        final minute = await notificationService.getSyncReminderMinute();
        await notificationService.scheduleSyncReminder(
          hour: hour,
          minute: minute,
        );
      }
    }
  }
}
