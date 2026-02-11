/// API configuration for the wealth tracker app.
/// Server URL is configurable since users can self-host.
class ApiConfig {
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Extended timeout for sync operations that may require 2FA approval.
  /// FinTS banks like DKB poll for up to 5 minutes waiting for push approval.
  static const Duration syncTimeout = Duration(minutes: 6);

  /// API endpoints
  static const String loginPath = '/api/auth/login/';
  static const String refreshPath = '/api/auth/refresh/';
  static const String mePath = '/api/auth/me/';
  static const String saltPath = '/api/auth/salt/';
  static const String newSaltPath = '/api/auth/salt/new/';
  static const String setupEncryptionPath = '/api/auth/setup-encryption/';
  static const String changePasswordPath = '/api/auth/change-password/kek/';
  static const String profilePath = '/api/profile/';
  static const String accountsPath = '/api/accounts/';
  static const String wealthSummaryPath = '/api/wealth/summary/';
  static const String wealthHistoryPath = '/api/wealth/history/';
  static const String deviceRegisterPath = '/api/devices/register/';

  static String accountSnapshotsPath(int accountId) =>
      '/api/accounts/$accountId/snapshots/';

  static String snapshotDetailPath(int snapshotId) =>
      '/api/snapshots/$snapshotId/';

  static String accountSyncPath(int accountId) =>
      '/api/accounts/$accountId/sync/';

  static const String syncAllPath = '/api/accounts/sync/';
}
