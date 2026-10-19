/// App-level configuration constants and setting defaults.
class AppConfig {
  /// Hours since last sync before sync-on-app-open triggers again.
  static const int syncSuppressionThresholdHours = 20;

  /// Days since the last sync at which an account that needs a code (and is
  /// therefore skipped by unattended syncs) is flagged, in three steps of
  /// growing urgency.
  static const int staleSyncNoticeDays = 21;
  static const int staleSyncWarningDays = 25;
  static const int staleSyncUrgentDays = 28;

  /// Default chart time range in days.
  static const int defaultChartRange = 365;

  /// Default chart granularity ('daily' or 'monthly').
  static const String defaultChartGranularity = 'daily';

  /// Default sync reminder hour (24h format).
  static const int defaultSyncReminderHour = 9;

  /// Default sync reminder minute.
  static const int defaultSyncReminderMinute = 0;

  /// Default date format preference.
  /// Values: 'system', 'dmy' (DD.MM.YYYY), 'mdy' (MM/DD/YYYY), 'ymd' (YYYY-MM-DD)
  static const String defaultDateFormat = 'system';

  /// Default theme mode preference.
  /// Values: 'system', 'light', 'dark'
  static const String defaultThemeMode = 'system';
}
