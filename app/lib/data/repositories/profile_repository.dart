import '../../core/config/api_config.dart';
import '../datasources/api_client.dart';
import '../models/profile.dart';

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  /// Fetch the user's profile.
  Future<Profile> getProfile() async {
    final response = await _apiClient.get(ApiConfig.profilePath);
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update the user's profile.
  Future<Profile> updateProfile({
    String? baseCurrency,
    bool? autoSyncEnabled,
    bool? sendWeeklyReport,
    int? defaultChartRange,
    String? defaultChartGranularity,
    bool? pushNotificationsEnabled,
    bool? pushWeeklyReport,
    bool? syncOnAppOpen,
  }) async {
    final data = <String, dynamic>{};

    if (baseCurrency != null) data['base_currency'] = baseCurrency;
    if (autoSyncEnabled != null) data['auto_sync_enabled'] = autoSyncEnabled;
    if (sendWeeklyReport != null) data['send_weekly_report'] = sendWeeklyReport;
    if (defaultChartRange != null) {
      data['default_chart_range'] = defaultChartRange;
    }
    if (defaultChartGranularity != null) {
      data['default_chart_granularity'] = defaultChartGranularity;
    }
    if (pushNotificationsEnabled != null) {
      data['push_notifications_enabled'] = pushNotificationsEnabled;
    }
    if (pushWeeklyReport != null) data['push_weekly_report'] = pushWeeklyReport;
    if (syncOnAppOpen != null) data['sync_on_app_open'] = syncOnAppOpen;

    final response = await _apiClient.patch(ApiConfig.profilePath, data: data);
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }
}
