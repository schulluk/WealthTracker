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
    StateNotifierProvider<SyncAllNotifier, SyncAllState>((ref) {
  return SyncAllNotifier(ref);
});

class SyncAllNotifier extends StateNotifier<SyncAllState> {
  final Ref _ref;

  SyncAllNotifier(this._ref) : super(const SyncAllState()) {
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final notificationService = _ref.read(notificationServiceProvider);
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
      final repository = _ref.read(accountRepositoryProvider);
      final notificationService = _ref.read(notificationServiceProvider);

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
      _ref.invalidate(accountsProvider);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  /// Check if sync should run based on suppression threshold.
  Future<bool> shouldSync() async {
    final notificationService = _ref.read(notificationServiceProvider);
    return notificationService.shouldSync();
  }

  /// Try to sync on app open if enabled and not recently synced.
  Future<void> trySyncOnAppOpen() async {
    final profile = await _ref.read(profileProvider.future);
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

/// Provider to update sync settings in the profile.
final syncSettingsProvider = Provider((ref) => SyncSettingsManager(ref));

class SyncSettingsManager {
  final Ref _ref;

  SyncSettingsManager(this._ref);

  /// Update sync reminder settings.
  Future<void> updateSyncSettings({
    bool? syncReminderEnabled,
    int? syncReminderHour,
    int? syncReminderMinute,
    bool? syncOnAppOpen,
  }) async {
    final repository = _ref.read(profileRepositoryProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    // Update on server
    await repository.updateProfile(
      syncReminderEnabled: syncReminderEnabled,
      syncReminderHour: syncReminderHour,
      syncReminderMinute: syncReminderMinute,
      syncOnAppOpen: syncOnAppOpen,
    );

    // Update local notifications
    final profile = await _ref.read(profileProvider.future);
    if (profile != null) {
      final enabled = syncReminderEnabled ?? profile.syncReminderEnabled;
      final hour = syncReminderHour ?? profile.syncReminderHour;
      final minute = syncReminderMinute ?? profile.syncReminderMinute;

      if (enabled) {
        await notificationService.scheduleSyncReminder(
          hour: hour,
          minute: minute,
        );
      } else {
        await notificationService.cancelSyncReminder();
      }
    }

    // Refresh profile
    _ref.invalidate(profileProvider);
  }

  /// Initialize sync reminders from profile settings.
  Future<void> initializeSyncReminders() async {
    final profile = await _ref.read(profileProvider.future);
    if (profile == null) return;

    final notificationService = _ref.read(notificationServiceProvider);
    await notificationService.initialize();

    if (profile.syncReminderEnabled) {
      await notificationService.requestPermissions();
      await notificationService.scheduleSyncReminder(
        hour: profile.syncReminderHour,
        minute: profile.syncReminderMinute,
      );
    }
  }
}
