/// App-level configuration constants and setting defaults.
class AppConfig {
  /// Hours since last sync before sync-on-app-open triggers again.
  static const int syncSuppressionThresholdHours = 20;

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
