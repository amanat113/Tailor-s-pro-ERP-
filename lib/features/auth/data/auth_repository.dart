import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../app/core/firebase/firebase_bootstrap.dart';
import '../../../app/core/security/pin_hasher.dart';
import '../../../app/core/storage/local_key_value_store.dart';
import '../../../app/core/utils/validators.dart';
import '../domain/app_role.dart';
import '../domain/app_session.dart';
import '../domain/user_profile.dart';

class OtpRequestResult {
  const OtpRequestResult({required this.verificationId, required this.isFirebase});

  final String verificationId;
  final bool isFirebase;
}

class VerifiedIdentity {
  const VerifiedIdentity({required this.uid, required this.mobile});

  final String uid;
  final String mobile;
}

class AuthRepository {
  AuthRepository({required this.firebaseStatus, required this.localStore});

  final FirebaseStatus firebaseStatus;
  final LocalKeyValueStore localStore;

  static const String _sessionKey = 'tailors_erp.session.v1';
  static const String _localUserPrefix = 'tailors_erp.user.';
  static const String _shopId = 'default_shop';

  bool get isFirebaseEnabled => firebaseStatus.enabled;

  Future<OtpRequestResult> requestOtp({
    required String mobile,
    required void Function(String verificationId) codeSent,
    required void Function(String error) failed,
  }) async {
    final normalized = Validators.normalizeIndianMobile(mobile);

    if (!isFirebaseEnabled) {
      const offlineVerificationId = 'offline-demo-verification-id';
      scheduleMicrotask(() => codeSent(offlineVerificationId));
      return const OtpRequestResult(
        verificationId: offlineVerificationId,
        isFirebase: false,
      );
    }

    final completer = Completer<OtpRequestResult>();
    await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (exception) {
        final message = exception.message ?? 'OTP verification failed.';
        failed(message);
        if (!completer.isCompleted) {
          completer.completeError(StateError(message));
        }
      },
      codeSent: (verificationId, resendToken) {
        codeSent(verificationId);
        if (!completer.isCompleted) {
          completer.complete(
            OtpRequestResult(verificationId: verificationId, isFirebase: true),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            OtpRequestResult(verificationId: verificationId, isFirebase: true),
          );
        }
      },
    );

    return completer.future;
  }

  Future<VerifiedIdentity> verifyOtp({
    required String mobile,
    required String otp,
    required String verificationId,
    required bool isFirebaseOtp,
  }) async {
    final normalized = Validators.normalizeIndianMobile(mobile);

    if (!isFirebaseOtp || !isFirebaseEnabled) {
      if (otp != '123456') {
        throw StateError('Invalid demo OTP. Use 123456 for offline mode.');
      }
      return VerifiedIdentity(uid: 'offline_${normalized.replaceAll('+', '')}', mobile: normalized);
    }

    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final userCredential =
        await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }
    return VerifiedIdentity(uid: user.uid, mobile: normalized);
  }

  Future<UserProfile?> loadProfile(String mobile) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final local = await _loadLocalProfile(normalized);

    if (!isFirebaseEnabled) return local;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopId)
          .collection('users')
          .doc(_documentIdForMobile(normalized))
          .get();
      if (!doc.exists || doc.data() == null) return local;
      final profile = UserProfile.fromMap(_firestoreToStringMap(doc.data()!));
      await _saveLocalProfile(profile);
      return profile;
    } on Object {
      return local;
    }
  }

  Future<UserProfile> createOrUpdatePin({
    required String uid,
    required String mobile,
    required String pin,
  }) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final hash = PinHasher.createHash(mobile: normalized, pin: pin);
    final now = DateTime.now();
    final existing = await loadProfile(normalized);
    final profile = UserProfile(
      uid: uid,
      mobile: normalized,
      pinSalt: hash.salt,
      pinHash: hash.hash,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _saveProfile(profile);
    return profile;
  }

  Future<bool> verifyPin({required String mobile, required String pin}) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final profile = await loadProfile(normalized);
    if (profile == null) return false;
    return PinHasher.verify(
      mobile: normalized,
      pin: pin,
      salt: profile.pinSalt,
      expectedHash: profile.pinHash,
    );
  }

  Future<void> saveSession(AppSession session) async {
    await localStore.writeString(_sessionKey, session.toJson());
  }

  Future<AppSession?> loadSession() async {
    final raw = await localStore.readString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return AppSession.fromJson(raw);
    } on Object {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    await localStore.remove(_sessionKey);
    if (isFirebaseEnabled) {
      await firebase_auth.FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await _saveLocalProfile(profile);
    if (!isFirebaseEnabled) return;

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopId)
        .collection('users')
        .doc(_documentIdForMobile(profile.mobile))
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> _saveLocalProfile(UserProfile profile) async {
    await localStore.writeString('$_localUserPrefix${_documentIdForMobile(profile.mobile)}', profile.toJson());
  }

  Future<UserProfile?> _loadLocalProfile(String mobile) async {
    final raw = await localStore.readString('$_localUserPrefix${_documentIdForMobile(mobile)}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return UserProfile.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  static String _documentIdForMobile(String mobile) {
    return mobile.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static Map<String, dynamic> _firestoreToStringMap(Map<String, dynamic> data) {
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return <String, dynamic>{
      ...data,
      'createdAt': created is Timestamp ? created.toDate().toIso8601String() : '${data['createdAt'] ?? ''}',
      'updatedAt': updated is Timestamp ? updated.toDate().toIso8601String() : '${data['updatedAt'] ?? ''}',
    };
  }

  Future<void> writeAuditLog({
    required String actorMobile,
    required AppRole role,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    if (!isFirebaseEnabled) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopId)
        .collection('auditLogs')
        .add(<String, dynamic>{
      'actorMobile': actorMobile,
      'role': role.storageValue,
      'action': action,
      'payloadJson': jsonEncode(payload),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
