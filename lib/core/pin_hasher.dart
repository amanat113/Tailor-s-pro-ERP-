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
    final saltBytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    return PinHashResult(salt: salt, hash: _hash(mobile: mobile, pin: pin, salt: salt));
  }

  static bool verify({
    required String mobile,
    required String pin,
    required String salt,
    required String expectedHash,
  }) {
    return _hash(mobile: mobile, pin: pin, salt: salt) == expectedHash;
  }

  static String _hash({required String mobile, required String pin, required String salt}) {
    final bytes = utf8.encode('$mobile:$pin:$salt:tailors_erp_secure_pin_v2');
    return sha256.convert(bytes).toString();
  }
}
