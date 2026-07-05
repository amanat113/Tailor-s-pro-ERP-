import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../core/app_constants.dart';
import '../core/pin_hasher.dart';
import '../core/validators.dart';
import '../models/app_role.dart';
import '../models/app_session.dart';
import '../models/user_profile.dart';
import '../services/local_store.dart';
import 'firestore_paths.dart';

class OtpRequestResult {
  const OtpRequestResult({required this.verificationId});
  final String verificationId;
}

class VerifiedIdentity {
  const VerifiedIdentity({required this.uid, required this.mobile});
  final String uid;
  final String mobile;
}

class AuthRepository {
  AuthRepository({required this.localStore});

  final LocalStore localStore;

  Future<OtpRequestResult> requestOtp({
    required String mobile,
    required void Function(String verificationId) codeSent,
    required void Function(String error) failed,
  }) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final completer = Completer<OtpRequestResult>();
    await auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await auth.FirebaseAuth.instance.signInWithCredential(credential);
        } on Object catch (error) {
          failed('$error');
        }
      },
      verificationFailed: (exception) {
        final message = exception.message ?? 'OTP verification failed. Check Firebase Phone Auth and SHA fingerprint.';
        failed(message);
        if (!completer.isCompleted) completer.completeError(StateError(message));
      },
      codeSent: (verificationId, resendToken) {
        codeSent(verificationId);
        if (!completer.isCompleted) completer.complete(OtpRequestResult(verificationId: verificationId));
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(OtpRequestResult(verificationId: verificationId));
      },
    );
    return completer.future;
  }

  Future<VerifiedIdentity> verifyOtp({required String mobile, required String otp, required String verificationId}) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final credential = auth.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
    final userCredential = await auth.FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) throw StateError('Firebase did not return a signed-in user.');
    return VerifiedIdentity(uid: user.uid, mobile: normalized);
  }

  Future<UserProfile?> loadProfile(String mobile) async {
    final docId = _docId(mobile);
    final doc = await FirestorePaths.users().doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = _normalizeDates(doc.data()!);
    return UserProfile.fromMap(data);
  }

  Future<UserProfile> createOrUpdatePin({required String uid, required String mobile, required String pin}) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final existing = await loadProfile(normalized);
    final hash = PinHasher.createHash(mobile: normalized, pin: pin);
    final now = DateTime.now();
    final profile = UserProfile(
      uid: uid,
      mobile: normalized,
      pinSalt: hash.salt,
      pinHash: hash.hash,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await FirestorePaths.users().doc(_docId(normalized)).set(profile.toMap(), SetOptions(merge: true));
    return profile;
  }

  Future<bool> verifyPin({required String mobile, required String pin}) async {
    final normalized = Validators.normalizeIndianMobile(mobile);
    final profile = await loadProfile(normalized);
    if (profile == null) return false;
    return PinHasher.verify(mobile: normalized, pin: pin, salt: profile.pinSalt, expectedHash: profile.pinHash);
  }

  Future<void> saveSession(AppSession session) async => localStore.write(AppConstants.appSessionKey, session.toJson());

  Future<AppSession?> loadSession() async {
    final raw = await localStore.read(AppConstants.appSessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final session = AppSession.fromJson(raw);
      return session.isExpired ? null : session;
    } on Object {
      return null;
    }
  }

  Future<void> clearSession() async {
    await localStore.remove(AppConstants.appSessionKey);
    await auth.FirebaseAuth.instance.signOut();
  }

  Future<void> writeAuditLog({
    required String actorMobile,
    required AppRole role,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await FirestorePaths.auditLogs().add(<String, dynamic>{
      'actorMobile': actorMobile,
      'role': role.value,
      'action': action,
      'payload': payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _docId(String mobile) => Validators.normalizeIndianMobile(mobile).replaceAll(RegExp(r'[^0-9]'), '');

  static Map<String, dynamic> _normalizeDates(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    for (final key in <String>['createdAt', 'updatedAt']) {
      final value = copy[key];
      if (value is Timestamp) copy[key] = value.toDate().toIso8601String();
    }
    return copy;
  }
}
