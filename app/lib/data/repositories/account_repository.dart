import '../../core/config/api_config.dart';
import '../datasources/api_client.dart';
import '../models/account.dart';
import '../models/snapshot.dart';

class AccountRepository {
  final ApiClient _apiClient;

  AccountRepository(this._apiClient);

  /// Fetch all accounts for the current user.
  Future<List<Account>> getAccounts() async {
    final response = await _apiClient.get(ApiConfig.accountsPath);
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((json) => Account.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch snapshots for a specific account. Follows pagination links so the
  /// caller gets the full history (the chart needs every snapshot, not just
  /// the most recent page).
  Future<List<AccountSnapshot>> getSnapshots(int accountId) async {
    final all = <AccountSnapshot>[];
    String? url = ApiConfig.accountSnapshotsPath(accountId);
    while (url != null) {
      final response = await _apiClient.get(url);
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      all.addAll(results
          .map((json) => AccountSnapshot.fromJson(json as Map<String, dynamic>)));
      final next = data['next'] as String?;
      url = next; // DRF returns absolute URL; ApiClient handles it
    }
    return all;
  }

  /// Add a new snapshot to an account.
  Future<AccountSnapshot> addSnapshot({
    required int accountId,
    required double balance,
    required String currency,
    required DateTime snapshotDate,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.accountSnapshotsPath(accountId),
      data: {
        'balance': balance.toString(),
        'currency': currency,
        'snapshot_date':
            '${snapshotDate.year}-${snapshotDate.month.toString().padLeft(2, '0')}-${snapshotDate.day.toString().padLeft(2, '0')}',
      },
    );
    return AccountSnapshot.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update an existing snapshot.
  Future<AccountSnapshot> updateSnapshot({
    required int snapshotId,
    required double balance,
    required String currency,
    required DateTime snapshotDate,
  }) async {
    final response = await _apiClient.put(
      ApiConfig.snapshotDetailPath(snapshotId),
      data: {
        'balance': balance.toString(),
        'currency': currency,
        'snapshot_date':
            '${snapshotDate.year}-${snapshotDate.month.toString().padLeft(2, '0')}-${snapshotDate.day.toString().padLeft(2, '0')}',
      },
    );
    return AccountSnapshot.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a snapshot.
  Future<void> deleteSnapshot(int snapshotId) async {
    await _apiClient.delete(ApiConfig.snapshotDetailPath(snapshotId));
  }

  /// Start sync for a single account (returns immediately with task ID).
  Future<Map<String, dynamic>> syncAccount(int accountId) async {
    final response = await _apiClient.post(
      ApiConfig.accountSyncPath(accountId),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Start sync for all accounts (returns immediately with task ID).
  Future<Map<String, dynamic>> syncAllAccounts() async {
    final response = await _apiClient.post(ApiConfig.syncAllPath);
    return response.data as Map<String, dynamic>;
  }

  /// Poll for the status of a background sync task.
  Future<Map<String, dynamic>> getSyncTaskStatus(String taskId) async {
    final response = await _apiClient.get(
      ApiConfig.syncTaskStatusPath(taskId),
    );
    return response.data as Map<String, dynamic>;
  }
}
