import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinHashResult {
  const PinHashResult({required this.salt, required this.hash});

  final String salt;
  final String hash;
}

class PinHasher {
  PinHasher._();

  static PinHashResult createHash({required String mobile, required String pin}) {
    final salt = _secureSalt();
    final hash = _digest(mobile: mobile, pin: pin, salt: salt);
    return PinHashResult(salt: salt, hash: hash);
  }

  static bool verify({
    required String mobile,
    required String pin,
    required String salt,
    required String expectedHash,
  }) {
    final actual = _digest(mobile: mobile, pin: pin, salt: salt);
    return actual == expectedHash;
  }

  static String _digest({
    required String mobile,
    required String pin,
    required String salt,
  }) {
    final normalizedMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final bytes = utf8.encode('$salt|$normalizedMobile|$pin|tailors-erp-v1');
    return sha256.convert(bytes).toString();
  }

  static String _secureSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
