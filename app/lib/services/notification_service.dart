import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/config/app_config.dart';
import '../main.dart' show notificationTapStream;
import 'us_market_holidays.dart';

/// Result of a notification permission request.
enum NotificationPermissionResult {
  /// Permission was granted.
  granted,

  /// Permission was denied (user can be asked again).
  denied,

  /// Permission was permanently denied (user must enable in settings).
  permanentlyDenied,
}

/// How often the sync reminder repeats.
enum NotificationFrequency {
  daily('daily', 1),
  every3Days('every3days', 3),
  weekly('weekly', 7),
  monthly('monthly', 0);

  const NotificationFrequency(this.key, this.intervalDays);

  /// Stable identifier persisted in SharedPreferences.
  final String key;

  /// Days between occurrences. Zero for [monthly], which is computed by
  /// calendar month rather than a fixed day interval.
  final int intervalDays;

  static NotificationFrequency fromKey(String? key) {
    return NotificationFrequency.values.firstWhere(
      (f) => f.key == key,
      orElse: () => NotificationFrequency.every3Days,
    );
  }
}

/// Service for managing local notifications, particularly sync reminders.
class NotificationService {
  static const String _lastSyncAllKey = 'last_sync_all_timestamp';
  static const String _syncReminderEnabledKey = 'sync_reminder_enabled';
  static const String _syncReminderHourKey = 'sync_reminder_hour';
  static const String _syncReminderMinuteKey = 'sync_reminder_minute';
  static const String _syncReminderFrequencyKey = 'sync_reminder_frequency';
  static const String _syncReminderShiftWeekendKey =
      'sync_reminder_shift_weekend';
  static const String _syncReminderSkipHolidaysKey =
      'sync_reminder_skip_holidays';

  /// Legacy single-notification id (pre-frequency feature). Cancelled on
  /// reschedule so old auto-repeating reminders don't linger.
  static const int _syncReminderNotificationId = 1;

  /// Reminders are scheduled as a rolling window of one-shot notifications
  /// occupying ids [_syncReminderBaseId] .. [_syncReminderBaseId] +
  /// [_syncReminderCount] - 1, re-topped-up whenever the app opens.
  static const int _syncReminderBaseId = 100;
  static const int _syncReminderCount = 12;

  static const String _syncReminderChannelId = 'sync_reminder';
  static const String _syncReminderChannelName = 'Sync Reminders';
  static const String _syncReminderChannelDesc =
      'Reminders to sync your accounts';

  /// Suppression threshold in hours. If last sync was within this time,
  /// skip the sync-on-app-open.
  static const int suppressionThresholdHours =
      AppConfig.syncSuppressionThresholdHours;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      notificationTapStream.add(response.payload!);
    }
  }

  /// Check the current notification permission status.
  Future<PermissionStatus> getNotificationPermissionStatus() async {
    return Permission.notification.status;
  }

  /// Check if notification permissions are granted.
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Check if notification permissions are permanently denied.
  ///
  /// On iOS, this means the user has explicitly denied and must go to settings.
  /// On Android 13+, this also applies after denying the runtime permission.
  Future<bool> isNotificationPermissionPermanentlyDenied() async {
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied;
  }

  /// Request notification permissions.
  ///
  /// Returns the result of the permission request.
  Future<NotificationPermissionResult> requestPermissions() async {
    // Check current status first
    var status = await Permission.notification.status;

    // If already granted, return immediately
    if (status.isGranted) {
      return NotificationPermissionResult.granted;
    }

    // If permanently denied on iOS, user must go to settings
    if (status.isPermanentlyDenied) {
      return NotificationPermissionResult.permanentlyDenied;
    }

    // Request permission
    if (Platform.isIOS) {
      // On iOS, use the flutter_local_notifications plugin for the initial request
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        if (granted == true) {
          return NotificationPermissionResult.granted;
        }

        // Check if now permanently denied
        status = await Permission.notification.status;
        if (status.isPermanentlyDenied) {
          return NotificationPermissionResult.permanentlyDenied;
        }

        return NotificationPermissionResult.denied;
      }
    } else if (Platform.isAndroid) {
      // On Android 13+, request the notification permission
      status = await Permission.notification.request();

      if (status.isGranted) {
        return NotificationPermissionResult.granted;
      }

      if (status.isPermanentlyDenied) {
        return NotificationPermissionResult.permanentlyDenied;
      }

      return NotificationPermissionResult.denied;
    }

    // Fallback for other platforms
    return NotificationPermissionResult.granted;
  }

  /// Schedule sync reminders at [hour]:[minute] according to [frequency].
  ///
  /// Because [frequency] (and the weekend/holiday shifting) can't be expressed
  /// with the platform's native repeat rules, the next [_syncReminderCount]
  /// occurrences are computed here and scheduled as individual one-shot
  /// notifications. The window is re-topped-up whenever the app opens.
  ///
  /// When [shiftWeekend] is set, an occurrence landing on a Saturday/Sunday is
  /// moved forward to the next weekday; subsequent occurrences are then
  /// re-anchored from that shifted date (so e.g. every-3-days starting Monday
  /// yields Mon, Thu, Mon, Thu instead of Mon, Thu, Sun, Wed). When
  /// [skipHolidays] is additionally set, US market holidays are treated the
  /// same way. Reminders may still be suppressed on open if the user has
  /// synced within the last 20 hours.
  Future<void> scheduleSyncReminder({
    required int hour,
    required int minute,
    required NotificationFrequency frequency,
    required bool shiftWeekend,
    required bool skipHolidays,
  }) async {
    await cancelSyncReminder();

    const androidDetails = AndroidNotificationDetails(
      _syncReminderChannelId,
      _syncReminderChannelName,
      channelDescription: _syncReminderChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final occurrences = _computeOccurrences(
      hour: hour,
      minute: minute,
      frequency: frequency,
      shiftWeekend: shiftWeekend,
      skipHolidays: skipHolidays,
      count: _syncReminderCount,
    );

    for (var i = 0; i < occurrences.length; i++) {
      await _notifications.zonedSchedule(
        id: _syncReminderBaseId + i,
        title: 'Wealth Tracker',
        body: 'Time to sync your accounts',
        scheduledDate: occurrences[i],
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'sync_reminder',
      );
    }

    debugPrint(
      'Scheduled ${occurrences.length} sync reminders (${frequency.key}) '
      'at $hour:$minute',
    );
  }

  /// Cancel all scheduled sync reminders (including the legacy single one).
  Future<void> cancelSyncReminder() async {
    await _notifications.cancel(id: _syncReminderNotificationId);
    for (var i = 0; i < _syncReminderCount; i++) {
      await _notifications.cancel(id: _syncReminderBaseId + i);
    }
  }

  /// Compute the next [count] future reminder times for [frequency].
  List<tz.TZDateTime> _computeOccurrences({
    required int hour,
    required int minute,
    required NotificationFrequency frequency,
    required bool shiftWeekend,
    required bool skipHolidays,
    required int count,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    final occurrences = <tz.TZDateTime>[];

    if (frequency == NotificationFrequency.monthly) {
      // Each month independently picks the anchor day-of-month, then shifts,
      // so the cadence doesn't drift across months.
      final anchorDay = now.day;
      var year = now.year;
      var month = now.month;
      var guard = 0;
      while (occurrences.length < count && guard < count * 3 + 12) {
        guard++;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = anchorDay > lastDay ? lastDay : anchorDay;
        final shifted = _applyShift(
          tz.TZDateTime(tz.local, year, month, day, hour, minute),
          shiftWeekend,
          skipHolidays,
        );
        if (shifted.isAfter(now)) occurrences.add(shifted);
        if (++month > 12) {
          month = 1;
          year++;
        }
      }
      return occurrences;
    }

    final interval = frequency.intervalDays;
    var current = _applyShift(
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute),
      shiftWeekend,
      skipHolidays,
    );
    var guard = 0;
    while (occurrences.length < count && guard < count * 4 + 30) {
      guard++;
      if (current.isAfter(now)) occurrences.add(current);
      current = _applyShift(
        _addDays(current, interval),
        shiftWeekend,
        skipHolidays,
      );
    }
    return occurrences;
  }

  /// Move [date] forward past weekends (when [shiftWeekend] is set) and/or US
  /// market holidays (when [skipHolidays] is set). The two toggles are
  /// independent: with only [skipHolidays] enabled, a holiday is moved to the
  /// next non-holiday day even if that day is a weekend, and vice versa.
  tz.TZDateTime _applyShift(
    tz.TZDateTime date,
    bool shiftWeekend,
    bool skipHolidays,
  ) {
    if (!shiftWeekend && !skipHolidays) return date;
    var d = date;
    for (var guard = 0; guard < 14; guard++) {
      final isWeekend =
          d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      if ((shiftWeekend && isWeekend) ||
          (skipHolidays && UsMarketHolidays.isHoliday(d))) {
        d = _addDays(d, 1);
      } else {
        return d;
      }
    }
    return d;
  }

  /// Add [days] to [d] preserving the wall-clock time across DST changes.
  tz.TZDateTime _addDays(tz.TZDateTime d, int days) {
    return tz.TZDateTime(
      tz.local,
      d.year,
      d.month,
      d.day + days,
      d.hour,
      d.minute,
    );
  }

  // --- Local sync reminder settings ---

  Future<bool> isSyncReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncReminderEnabledKey) ?? false;
  }

  Future<void> setSyncReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncReminderEnabledKey, enabled);
  }

  Future<int> getSyncReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncReminderHourKey) ?? AppConfig.defaultSyncReminderHour;
  }

  Future<int> getSyncReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncReminderMinuteKey) ?? AppConfig.defaultSyncReminderMinute;
  }

  Future<void> setSyncReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncReminderHourKey, hour);
    await prefs.setInt(_syncReminderMinuteKey, minute);
  }

  Future<NotificationFrequency> getSyncReminderFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationFrequency.fromKey(
      prefs.getString(_syncReminderFrequencyKey),
    );
  }

  Future<void> setSyncReminderFrequency(NotificationFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncReminderFrequencyKey, frequency.key);
  }

  Future<bool> getSyncReminderShiftWeekend() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncReminderShiftWeekendKey) ?? false;
  }

  Future<void> setSyncReminderShiftWeekend(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncReminderShiftWeekendKey, value);
  }

  Future<bool> getSyncReminderSkipHolidays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncReminderSkipHolidaysKey) ?? false;
  }

  Future<void> setSyncReminderSkipHolidays(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncReminderSkipHolidaysKey, value);
  }

  /// Record a sync-all operation timestamp.
  Future<void> recordSyncAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncAllKey, DateTime.now().toIso8601String());
  }

  /// Get the last sync-all timestamp.
  Future<DateTime?> getLastSyncAll() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncAllKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Check if a sync is needed based on the suppression threshold.
  ///
  /// Returns true if:
  /// - No previous sync recorded
  /// - Last sync was more than [suppressionThresholdHours] hours ago
  Future<bool> shouldSync() async {
    final lastSync = await getLastSyncAll();
    if (lastSync == null) return true;

    final hoursSinceSync = DateTime.now().difference(lastSync).inHours;
    return hoursSinceSync >= suppressionThresholdHours;
  }

  /// Clear the last sync timestamp.
  Future<void> clearLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncAllKey);
  }
}
