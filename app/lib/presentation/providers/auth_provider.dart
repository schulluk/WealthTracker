import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../data/models/user.dart';
import 'core_providers.dart';

/// Auth state - null means not authenticated.
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // Check if we have tokens on startup
    final storage = ref.read(secureStorageProvider);
    final hasTokens = await storage.hasTokens();

    if (!hasTokens) return null;

    // Try to validate the token
    try {
      return await _fetchCurrentUser();
    } catch (e) {
      // Token invalid, clear it
      await storage.clearTokens();
      return null;
    }
  }

  Future<User> _fetchCurrentUser() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(ApiConfig.mePath);
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get salts for a user from the server.
  /// Returns null if user doesn't exist or hasn't migrated.
  Future<({String? authSalt, String? kekSalt, bool migrated})> _getSalts(
      String username) async {
    final apiClient = ref.read(apiClientProvider);

    try {
      final response = await apiClient.get(
        ApiConfig.saltPath,
        queryParameters: {'username': username},
      );

      final data = response.data as Map<String, dynamic>;
      return (
        authSalt: data['auth_salt'] as String?,
        kekSalt: data['kek_salt'] as String?,
        migrated: data['encryption_migrated'] as bool? ?? false,
      );
    } catch (e) {
      // User might not exist or server doesn't support KEK auth
      debugPrint('Failed to get salts: $e');
      return (authSalt: null, kekSalt: null, migrated: false);
    }
  }

  /// Login with username and password.
  ///
  /// Supports both legacy (password) and KEK-based (auth_hash) authentication.
  Future<void> login(String username, String password) async {
    state = const AsyncLoading();

    try {
      final apiClient = ref.read(apiClientProvider);
      final storage = ref.read(secureStorageProvider);
      final cryptoService = ref.read(cryptoServiceProvider);

      // Try to get salts for KEK-based auth
      final salts = await _getSalts(username);

      Response response;

      if (salts.migrated &&
          salts.authSalt != null &&
          salts.kekSalt != null) {
        // User has migrated to per-user encryption
        // Derive auth_hash and KEK client-side (password never sent!)
        final keys = await cryptoService.deriveKeys(
          password: password,
          authSalt: salts.authSalt!,
          kekSalt: salts.kekSalt!,
        );

        // Login with auth_hash instead of password
        response = await apiClient.post(
          ApiConfig.loginPath,
          data: {
            'username': username,
            'auth_hash': keys.authHash,
          },
        );

        // Store KEK and salts for subsequent requests
        await storage.setKEK(keys.kek);
        await storage.setSalts(salts.authSalt!, salts.kekSalt!);
        await storage.setEncryptionMigrated(true);
      } else {
        // Legacy login with password
        response = await apiClient.post(
          ApiConfig.loginPath,
          data: {
            'username': username,
            'password': password,
          },
        );

        final accessToken = response.data['access'] as String;
        final refreshToken = response.data['refresh'] as String;
        await storage.setTokens(accessToken, refreshToken);

        // Auto-migrate to per-user encryption
        debugPrint('User not migrated, starting migration...');
        await _migrateToPerUserEncryption(password);
        return;
      }

      final accessToken = response.data['access'] as String;
      final refreshToken = response.data['refresh'] as String;

      await storage.setTokens(accessToken, refreshToken);

      // Fetch user info
      final user = await _fetchCurrentUser();
      state = AsyncData(user);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Migrate a legacy user to per-user encryption.
  ///
  /// This generates new salts, derives KEK/auth_hash, and calls
  /// the setup-encryption endpoint to re-encrypt all credentials.
  Future<void> _migrateToPerUserEncryption(String password) async {
    final apiClient = ref.read(apiClientProvider);
    final storage = ref.read(secureStorageProvider);
    final cryptoService = ref.read(cryptoServiceProvider);

    try {
      // Generate new salts
      final saltResponse = await apiClient.get(ApiConfig.newSaltPath);
      final newAuthSalt = saltResponse.data['auth_salt'] as String;
      final newKekSalt = saltResponse.data['kek_salt'] as String;

      // Derive keys from password
      final keys = await cryptoService.deriveKeys(
        password: password,
        authSalt: newAuthSalt,
        kekSalt: newKekSalt,
      );

      // Call setup-encryption to migrate credentials
      final setupResponse = await apiClient.post(
        ApiConfig.setupEncryptionPath,
        data: {
          'kek': keys.kek,
          'auth_hash': keys.authHash,
          'auth_salt': newAuthSalt,
          'kek_salt': newKekSalt,
        },
      );

      final accountsMigrated = setupResponse.data['accounts_migrated'] ?? 0;
      debugPrint('Migration complete: $accountsMigrated accounts migrated');

      // Store KEK and salts for subsequent requests
      await storage.setKEK(keys.kek);
      await storage.setSalts(newAuthSalt, newKekSalt);
      await storage.setEncryptionMigrated(true);

      // Fetch user info
      final user = await _fetchCurrentUser();
      state = AsyncData(user);
    } catch (e) {
      debugPrint('Migration failed: $e');
      // Clear tokens on migration failure - user needs to try again
      await storage.clearTokens();
      state = AsyncError(
        Exception('Migration to secure encryption failed: $e'),
        StackTrace.current,
      );
      rethrow;
    }
  }

  /// Logout and clear tokens.
  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.clearAll();
    state = const AsyncData(null);
  }

  /// Clear auth state without clearing tokens.
  /// Used when biometric fails but we want to allow password re-auth.
  void clearAuthState() {
    state = const AsyncData(null);
  }

  /// Attempt to unlock with biometrics.
  /// Returns true if successful.
  Future<bool> unlockWithBiometrics() async {
    final biometricService = ref.read(biometricServiceProvider);
    final storage = ref.read(secureStorageProvider);

    // Check if biometric is enabled
    final biometricEnabled = await storage.isBiometricEnabled();
    if (!biometricEnabled) return false;

    // Authenticate with biometrics
    final authenticated = await biometricService.authenticate();
    if (!authenticated) return false;

    // Validate token
    try {
      final user = await _fetchCurrentUser();
      state = AsyncData(user);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Provider to check if biometric unlock is available and enabled.
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final biometricService = ref.watch(biometricServiceProvider);
  final storage = ref.watch(secureStorageProvider);

  final isAvailable = await biometricService.isAvailable();
  final isEnabled = await storage.isBiometricEnabled();

  return isAvailable && isEnabled;
});

/// Provider to check if server URL is configured.
final hasServerUrlProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return await storage.hasServerUrl();
});
