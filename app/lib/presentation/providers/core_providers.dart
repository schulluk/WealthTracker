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
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final storage = ref.read(secureStorageProvider);
    final mode = await storage.getThemeMode();
    state = _parseThemeMode(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(secureStorageProvider);
    await storage.setThemeMode(_themeModeToString(mode));
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
    NotifierProvider<DateFormatNotifier, String>(DateFormatNotifier.new);

class DateFormatNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'system';
  }

  Future<void> _load() async {
    final storage = ref.read(secureStorageProvider);
    state = await storage.getDateFormat();
  }

  Future<void> setDateFormat(String format) async {
    state = format;
    final storage = ref.read(secureStorageProvider);
    await storage.setDateFormat(format);
  }
}
