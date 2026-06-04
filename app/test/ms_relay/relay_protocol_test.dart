import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wealth_tracker/services/ms_relay/relay_protocol.dart';

void main() {
  group('relay protocol wire format (must match backend protocol.py)', () {
    test('encodeFrame: type byte + big-endian uint32 stream id + payload', () {
      // streamId 0x01020304, DATA type, payload [0xAA, 0xBB]
      final frame = encodeFrame(RelayFrameType.data, 0x01020304, [0xAA, 0xBB]);
      expect(frame, equals([4, 1, 2, 3, 4, 0xAA, 0xBB]));
    });

    test('encodeFrame: empty payload (OPEN_OK)', () {
      final frame = encodeFrame(RelayFrameType.openOk, 7);
      expect(frame, equals([2, 0, 0, 0, 7]));
    });

    test('decodeFrame is the inverse of encodeFrame', () {
      final payload = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
      final encoded = encodeFrame(RelayFrameType.data, 0xDEADBEEF, payload);
      final decoded = decodeFrame(encoded);
      expect(decoded.type, RelayFrameType.data);
      expect(decoded.streamId, 0xDEADBEEF);
      expect(decoded.payload, equals(payload));
    });

    test('decodeOpen: hostlen(1) host(utf8) port(uint16 big-endian)', () {
      const host = 'atwork.morganstanley.com';
      const port = 443; // 0x01BB
      final payload = Uint8List.fromList([
        host.length,
        ...utf8.encode(host),
        (port >> 8) & 0xff,
        port & 0xff,
      ]);
      final open = decodeOpen(payload);
      expect(open.host, host);
      expect(open.port, port);
    });
  });
}
