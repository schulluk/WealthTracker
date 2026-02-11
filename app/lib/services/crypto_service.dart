import 'dart:convert';
import 'dart:typed_data';

import 'package:dargon2_flutter/dargon2_flutter.dart';

/// Service for cryptographic operations including Argon2 key derivation.
class CryptoService {
  /// Argon2id parameters matching the backend/React implementation.
  static const int _timeCost = 3;
  static const int _memoryCost = 65536; // 64 MB
  static const int _parallelism = 4;
  static const int _hashLength = 32;

  /// Derive a key from password and salt using Argon2id.
  ///
  /// Returns base64-encoded 32-byte key.
  Future<String> deriveKey(String password, String saltBase64) async {
    final salt = Salt(base64Decode(saltBase64));

    final result = await argon2.hashPasswordString(
      password,
      salt: salt,
      iterations: _timeCost,
      memory: _memoryCost,
      parallelism: _parallelism,
      length: _hashLength,
      type: Argon2Type.id,
    );

    return base64Encode(result.rawBytes);
  }

  /// Derive authentication hash from password and salt.
  ///
  /// This is sent to the server for authentication (password never sent).
  Future<String> deriveAuthHash(String password, String authSalt) async {
    return deriveKey(password, authSalt);
  }

  /// Derive KEK (Key Encryption Key) from password and salt.
  ///
  /// This is used to decrypt the user's encryption key.
  Future<String> deriveKEK(String password, String kekSalt) async {
    return deriveKey(password, kekSalt);
  }

  /// Derive both auth hash and KEK from password.
  ///
  /// Returns both values for efficiency when both are needed.
  Future<({String authHash, String kek})> deriveKeys({
    required String password,
    required String authSalt,
    required String kekSalt,
  }) async {
    // Run both derivations in parallel for better performance
    final results = await Future.wait([
      deriveAuthHash(password, authSalt),
      deriveKEK(password, kekSalt),
    ]);

    return (authHash: results[0], kek: results[1]);
  }

  /// Convert raw bytes to base64url encoding for Fernet compatibility.
  String bytesToBase64Url(Uint8List bytes) {
    return base64Url.encode(bytes);
  }

  /// Convert base64 string to bytes.
  Uint8List base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }
}
