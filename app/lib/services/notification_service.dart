import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications, particularly sync reminders.
class NotificationService {
  static const String _lastSyncAllKey = 'last_sync_all_timestamp';
  static const int _syncReminderNotificationId = 1;
  static const String _syncReminderChannelId = 'sync_reminder';
  static const String _syncReminderChannelName = 'Sync Reminders';
  static const String _syncReminderChannelDesc =
      'Daily reminders to sync your accounts';

  /// Suppression threshold in hours. If last sync was within this time,
  /// skip the notification.
  static const int suppressionThresholdHours = 20;

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
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Notification tap handling - app will open automatically
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions (iOS).
  Future<bool> requestPermissions() async {
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Schedule a daily sync reminder at the specified time.
  ///
  /// The notification will be shown daily at [hour]:[minute], but will be
  /// suppressed if the user has synced within the last 20 hours.
  Future<void> scheduleSyncReminder({
    required int hour,
    required int minute,
  }) async {
    await _notifications.cancel(_syncReminderNotificationId);

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

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      _syncReminderNotificationId,
      'Wealth Tracker',
      'Time to sync your accounts',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Daily repeat
      payload: 'sync_reminder',
    );

    debugPrint('Scheduled sync reminder for $hour:$minute');
  }

  /// Cancel the sync reminder notification.
  Future<void> cancelSyncReminder() async {
    await _notifications.cancel(_syncReminderNotificationId);
  }

  /// Get the next instance of the specified time.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
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
