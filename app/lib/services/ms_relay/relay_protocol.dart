import 'dart:convert';
import 'dart:typed_data';

/// Wire protocol for the MS relay — the Dart counterpart of the backend's
/// `brokers/ms_relay/protocol.py`. Each WebSocket binary message is one frame:
///
///     byte 0     : type
///     bytes 1..5 : stream id (uint32, big-endian)
///     bytes 5..  : payload (type-specific)
class RelayFrameType {
  static const int open = 1; // bridge -> exit: open TCP. payload = hostlen(1) host port(uint16)
  static const int openOk = 2; // exit -> bridge: connected
  static const int openErr = 3; // exit -> bridge: connect failed. payload = reason(utf8)
  static const int data = 4; // both: relay raw bytes
  static const int close = 5; // both: close the stream
}

class RelayFrame {
  final int type;
  final int streamId;
  final Uint8List payload;
  const RelayFrame(this.type, this.streamId, this.payload);
}

Uint8List encodeFrame(int type, int streamId, [List<int>? payload]) {
  final p = payload ?? const <int>[];
  final out = Uint8List(5 + p.length);
  out[0] = type;
  out[1] = (streamId >> 24) & 0xff;
  out[2] = (streamId >> 16) & 0xff;
  out[3] = (streamId >> 8) & 0xff;
  out[4] = streamId & 0xff;
  out.setRange(5, 5 + p.length, p);
  return out;
}

RelayFrame decodeFrame(Uint8List frame) {
  final type = frame[0];
  final streamId =
      (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4];
  return RelayFrame(type, streamId, Uint8List.sublistView(frame, 5));
}

/// (host, port) from an OPEN payload: hostlen(1) host(utf8) port(uint16, big-endian).
({String host, int port}) decodeOpen(Uint8List payload) {
  final hostLen = payload[0];
  final host = utf8.decode(payload.sublist(1, 1 + hostLen));
  final port = (payload[1 + hostLen] << 8) | payload[2 + hostLen];
  return (host: host, port: port);
}
