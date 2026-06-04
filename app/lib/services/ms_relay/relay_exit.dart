import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'relay_protocol.dart';

/// The phone's role in the MS relay: a dumb TCP exit node.
///
/// It connects to the server's `/ws/ms-relay/` WebSocket, then for each OPEN
/// frame opens a real TCP socket over the phone's own network (mobile/Wi-Fi —
/// a residential IP) and pipes raw, already-TLS-encrypted bytes both ways. It
/// never sees the Morgan Stanley session; it only forwards opaque bytes. This is
/// a 1:1 port of the Python `RelayExit` in `backend/brokers/ms_relay/exit_node.py`.
class RelayExit {
  final WebSocket _ws;
  final Map<int, Socket> _sockets = {};
  final Map<int, StreamSubscription<Uint8List>> _subs = {};
  bool _closed = false;
  final _doneCompleter = Completer<void>();

  RelayExit._(this._ws) {
    _ws.listen(
      _onMessage,
      onDone: close,
      onError: (_) => close(),
      cancelOnError: true,
    );
  }

  /// Opens the relay WebSocket (authenticated with the user's access token) and
  /// starts forwarding. Throws if the connection can't be established.
  static Future<RelayExit> connect(Uri wsUrl, {required String token}) async {
    final ws = await WebSocket.connect(
      wsUrl.toString(),
      headers: {'Authorization': 'Bearer $token'},
    );
    return RelayExit._(ws);
  }

  /// Completes when the relay closes (remote hang-up, error, or close()).
  Future<void> get done => _doneCompleter.future;

  void _send(Uint8List frame) {
    if (_closed) return;
    try {
      _ws.add(frame);
    } catch (_) {
      // WS gone — nothing to do; close() will clean up.
    }
  }

  void _onMessage(dynamic message) {
    if (message is! List<int>) return; // ignore text frames
    final bytes = message is Uint8List ? message : Uint8List.fromList(message);
    if (bytes.length < 5) return;
    final frame = decodeFrame(bytes);
    switch (frame.type) {
      case RelayFrameType.open:
        final target = decodeOpen(frame.payload);
        _open(frame.streamId, target.host, target.port);
        break;
      case RelayFrameType.data:
        final socket = _sockets[frame.streamId];
        if (socket != null) {
          try {
            socket.add(frame.payload);
          } catch (_) {
            _closeStream(frame.streamId);
          }
        }
        break;
      case RelayFrameType.close:
        _closeStream(frame.streamId);
        break;
    }
  }

  Future<void> _open(int sid, String host, int port) async {
    Socket socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      final reason = e.toString();
      _send(encodeFrame(
        RelayFrameType.openErr,
        sid,
        utf8.encode(reason.length > 120 ? reason.substring(0, 120) : reason),
      ));
      return;
    }
    if (_closed) {
      socket.destroy();
      return;
    }
    _sockets[sid] = socket;
    _send(encodeFrame(RelayFrameType.openOk, sid));
    // Pump target bytes -> DATA frames until the connection closes.
    _subs[sid] = socket.listen(
      (data) => _send(encodeFrame(RelayFrameType.data, sid, data)),
      onDone: () {
        _send(encodeFrame(RelayFrameType.close, sid));
        _closeStream(sid);
      },
      onError: (_) => _closeStream(sid),
      cancelOnError: true,
    );
  }

  void _closeStream(int sid) {
    _subs.remove(sid)?.cancel();
    final socket = _sockets.remove(sid);
    if (socket != null) {
      try {
        socket.destroy();
      } catch (_) {}
    }
  }

  /// Tear down every stream and the WebSocket.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final sid in _sockets.keys.toList()) {
      _closeStream(sid);
    }
    try {
      await _ws.close();
    } catch (_) {}
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    debugPrint('MS relay exit: closed');
  }
}
