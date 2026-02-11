import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/api_client.dart';
import '../../services/biometric_service.dart';
import '../../services/crypto_service.dart';
import '../../services/notification_service.dart';
import '../../services/secure_storage_service.dart';

/// Provider for the secure storage service.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for the crypto service (Argon2 key derivation).
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

/// Provider for the notification service (local notifications).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});

/// Provider for the biometric service.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// Provider for theme mode setting.
/// Values: 'system', 'light', 'dark'
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SecureStorageService _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final mode = await _storage.getThemeMode();
    state = _parseThemeMode(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.setThemeMode(_themeModeToString(mode));
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// Provider for date format setting.
/// Values: 'system', 'dmy', 'mdy', 'ymd'
final dateFormatProvider =
    StateNotifierProvider<DateFormatNotifier, String>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return DateFormatNotifier(storage);
});

class DateFormatNotifier extends StateNotifier<String> {
  final SecureStorageService _storage;

  DateFormatNotifier(this._storage) : super('system') {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getDateFormat();
  }

  Future<void> setDateFormat(String format) async {
    state = format;
    await _storage.setDateFormat(format);
  }
}
