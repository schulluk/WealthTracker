import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../data/datasources/api_client.dart';
import '../../data/models/account.dart';
import '../../presentation/providers/core_providers.dart';
import '../secure_storage_service.dart';
import 'background_keepalive.dart';
import 'relay_exit.dart';

/// Broker codes whose server-side sync needs the phone relay (residential IP).
const Set<String> relayBrokerCodes = {'morganstanley'};

/// Whether this account's sync needs the relay (a syncable Morgan Stanley account).
bool accountNeedsRelay(Account a) =>
    !a.isManual &&
    a.syncEnabled &&
    a.broker.supportsAutoSync &&
    relayBrokerCodes.contains(a.broker.code);

bool anyNeedsRelay(Iterable<Account> accounts) => accounts.any(accountNeedsRelay);

/// Opens the MS relay — making this phone the residential network exit — for the
/// duration of a sync, so the server can route the headless Morgan Stanley login
/// through the phone's IP instead of the (Akamai-blocked) datacenter IP.
///
/// A no-op when no account needs it. If the relay can't be opened, the sync still
/// runs; the server simply skips the MS account with an "open the app" message
/// rather than hanging.
class RelayService {
  final SecureStorageService _storage;
  final ApiClient _apiClient;

  RelayService(this._storage, this._apiClient);

  Future<T> withRelay<T>(
    Future<T> Function() action, {
    required bool active,
  }) async {
    if (!active) return action();

    final session = RelaySession(this);
    await session.start();
    try {
      return await action();
    } finally {
      await session.stop();
    }
  }

  /// Open one relay WebSocket. Throws if it can't be established.
  Future<RelayExit> connectOnce() async {
    // Keep the stored access token fresh (the WS auth has no refresh of its own);
    // a 401 here triggers the ApiClient interceptor's token refresh.
    try {
      await _apiClient.get(ApiConfig.mePath);
    } catch (_) {
      // Non-fatal — try with whatever token we have.
    }

    final serverUrl = await _storage.getServerUrl();
    final token = await _storage.getAccessToken();
    if (serverUrl == null || token == null) {
      throw StateError('relay not configured (missing server URL or token)');
    }

    final base = Uri.parse(serverUrl);
    final wsUri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/ms-relay/',
    );
    return RelayExit.connect(wsUri, token: token);
  }
}

/// Keeps a relay connected for the lifetime of one sync, surviving the app being
/// briefly backgrounded (e.g. to approve another account's 2FA): it reconnects
/// when the app resumes and after an unexpected drop. Because the server's sync
/// queue blocks on an interactive account's 2FA until the user returns, the relay
/// is live again before the Morgan Stanley account's turn comes.
class RelaySession with WidgetsBindingObserver {
  final RelayService _service;
  final BackgroundKeepAlive _keepAlive = BackgroundKeepAlive();
  RelayExit? _exit;
  bool _stopped = false;
  bool _connecting = false;
  int _failures = 0;
  static const int _maxFailures = 8;

  RelaySession(this._service);

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    // Request background execution so the relay survives a brief switch-away
    // (e.g. approving another account's 2FA) mid-sync.
    await _keepAlive.begin();
    await _connect();
  }

  Future<void> _connect() async {
    if (_stopped || _connecting || _exit != null) return;
    _connecting = true;
    try {
      final exit = await _service.connectOnce();
      if (_stopped) {
        await exit.close();
        return;
      }
      _exit = exit;
      _failures = 0;
      debugPrint('MS relay: connected — phone is the residential exit');
      // Reconnect if it drops unexpectedly while the sync is still running.
      exit.done.then((_) {
        if (_stopped || !identical(_exit, exit)) return;
        _exit = null;
        debugPrint('MS relay: connection dropped; attempting to reconnect');
        _reconnectSoon();
      });
    } catch (e) {
      _failures++;
      debugPrint('MS relay: connect failed ($e), attempt $_failures');
      if (_failures < _maxFailures) _reconnectSoon();
    } finally {
      _connecting = false;
    }
  }

  void _reconnectSoon() {
    if (_stopped || _exit != null) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!_stopped && _exit == null) _connect();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground: if the relay died while backgrounded
    // (iOS freezes/closes it), reconnect right away so it's live before the
    // server reaches the relayed account.
    if (state == AppLifecycleState.resumed && !_stopped && _exit == null) {
      _failures = 0;
      _connect();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    WidgetsBinding.instance.removeObserver(this);
    final exit = _exit;
    _exit = null;
    await exit?.close();
    await _keepAlive.end();
  }
}

final relayServiceProvider = Provider<RelayService>((ref) {
  return RelayService(
    ref.watch(secureStorageProvider),
    ref.watch(apiClientProvider),
  );
});
