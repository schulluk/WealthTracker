import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/config/app_config.dart';
import '../main.dart' show notificationTapStream;

/// Result of a notification permission request.
enum NotificationPermissionResult {
  /// Permission was granted.
  granted,

  /// Permission was denied (user can be asked again).
  denied,

  /// Permission was permanently denied (user must enable in settings).
  permanentlyDenied,
}

/// Service for managing local notifications, particularly sync reminders.
class NotificationService {
  static const String _lastSyncAllKey = 'last_sync_all_timestamp';
  static const String _syncReminderEnabledKey = 'sync_reminder_enabled';
  static const String _syncReminderHourKey = 'sync_reminder_hour';
  static const String _syncReminderMinuteKey = 'sync_reminder_minute';
  static const int _syncReminderNotificationId = 1;
  static const String _syncReminderChannelId = 'sync_reminder';
  static const String _syncReminderChannelName = 'Sync Reminders';
  static const String _syncReminderChannelDesc =
      'Daily reminders to sync your accounts';

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

  /// Schedule a daily sync reminder at the specified time.
  ///
  /// The notification will be shown daily at [hour]:[minute], but will be
  /// suppressed if the user has synced within the last 20 hours.
  Future<void> scheduleSyncReminder({
    required int hour,
    required int minute,
  }) async {
    await _notifications.cancel(id: _syncReminderNotificationId);

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
      id: _syncReminderNotificationId,
      title: 'Wealth Tracker',
      body: 'Time to sync your accounts',
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Daily repeat
      payload: 'sync_reminder',
    );

    debugPrint('Scheduled sync reminder for $hour:$minute');
  }

  /// Cancel the sync reminder notification.
  Future<void> cancelSyncReminder() async {
    await _notifications.cancel(id: _syncReminderNotificationId);
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
