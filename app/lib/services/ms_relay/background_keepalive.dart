import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Requests a short window of background execution so the relay keeps forwarding
/// bytes if the app is briefly backgrounded during a sync (e.g. switching to an
/// authenticator/banking app for another account's 2FA).
///
/// - iOS: `UIApplication.beginBackgroundTask` (~30s of execution after the app
///   backgrounds — enough for an in-flight MS login).
/// - Android: a partial wakelock so the CPU keeps running with the screen off.
/// - Other platforms / channel errors: a harmless no-op.
class BackgroundKeepAlive {
  static const MethodChannel _channel =
      MethodChannel('wealth/background_keepalive');
  bool _active = false;

  Future<void> begin() async {
    if (_active) return;
    _active = true;
    try {
      await _channel.invokeMethod<void>('begin');
    } catch (e) {
      debugPrint('BackgroundKeepAlive.begin failed: $e');
    }
  }

  Future<void> end() async {
    if (!_active) return;
    _active = false;
    try {
      await _channel.invokeMethod<void>('end');
    } catch (e) {
      debugPrint('BackgroundKeepAlive.end failed: $e');
    }
  }
}
