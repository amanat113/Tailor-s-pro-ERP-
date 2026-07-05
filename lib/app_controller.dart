import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core/firebase_bootstrap.dart';
import 'core/validators.dart';
import 'data/auth_repository.dart';
import 'models/app_role.dart';
import 'models/app_session.dart';
import 'models/user_profile.dart';

class AppState {
  const AppState({
    required this.firebaseStatus,
    required this.authStep,
    this.loading = false,
    this.error,
    this.info,
    this.mobile = '',
    this.verificationId = '',
    this.uid = '',
    this.profile,
    this.session,
    this.pageIndex = 0,
  });

  final FirebaseStatus firebaseStatus;
  final AuthStep authStep;
  final bool loading;
  final String? error;
  final String? info;
  final String mobile;
  final String verificationId;
  final String uid;
  final UserProfile? profile;
  final AppSession? session;
  final int pageIndex;

  AppState copyWith({
    FirebaseStatus? firebaseStatus,
    AuthStep? authStep,
    bool? loading,
    String? error,
    String? info,
    String? mobile,
    String? verificationId,
    String? uid,
    UserProfile? profile,
    AppSession? session,
    int? pageIndex,
    bool clearError = false,
    bool clearInfo = false,
    bool clearProfile = false,
    bool clearSession = false,
  }) {
    return AppState(
      firebaseStatus: firebaseStatus ?? this.firebaseStatus,
      authStep: authStep ?? this.authStep,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      info: clearInfo ? null : info ?? this.info,
      mobile: mobile ?? this.mobile,
      verificationId: verificationId ?? this.verificationId,
      uid: uid ?? this.uid,
      profile: clearProfile ? null : profile ?? this.profile,
      session: clearSession ? null : session ?? this.session,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }
}

enum AuthStep { booting, login, otp, pinSetup, pinLogin, role, app }

class AppController extends ChangeNotifier {
  AppController({required this.authRepository})
      : _state = const AppState(
          firebaseStatus: FirebaseStatus(enabled: false),
          authStep: AuthStep.booting,
        );

  final AuthRepository authRepository;
  AppState _state;
  AppState get state => _state;

  Timer? _securityTimer;
  DateTime _lastSessionSave = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start() async {
    _set(_state.copyWith(authStep: AuthStep.booting, loading: true, clearError: true, clearInfo: true));
    final firebase = await FirebaseBootstrap.initialize();
    if (!firebase.enabled) {
      _set(_state.copyWith(firebaseStatus: firebase, authStep: AuthStep.login, loading: false, error: firebase.message));
      return;
    }
    final session = await authRepository.loadSession();
    if (session != null && !session.isExpired) {
      _set(_state.copyWith(firebaseStatus: firebase, authStep: AuthStep.app, loading: false, mobile: session.mobile, uid: session.uid, session: session, info: 'Session restored.'));
    } else {
      _set(_state.copyWith(firebaseStatus: firebase, authStep: AuthStep.login, loading: false, info: 'Login required.'));
    }
    _securityTimer?.cancel();
    _securityTimer = Timer.periodic(const Duration(seconds: 30), (_) => validateSession());
  }

  Future<void> sendOtp(String mobileInput) async {
    final mobile = Validators.normalizeIndianMobile(mobileInput);
    if (!Validators.isValidIndianMobile(mobile)) {
      _set(_state.copyWith(error: 'Enter a valid Indian mobile number.', clearInfo: true));
      return;
    }
    _set(_state.copyWith(loading: true, mobile: mobile, clearError: true, clearInfo: true));
    try {
      final result = await authRepository.requestOtp(
        mobile: mobile,
        codeSent: (verificationId) {
          _set(_state.copyWith(authStep: AuthStep.otp, loading: false, verificationId: verificationId, info: 'OTP sent to $mobile.'));
        },
        failed: (error) => _set(_state.copyWith(loading: false, error: error, clearInfo: true)),
      );
      _set(_state.copyWith(loading: false, verificationId: result.verificationId));
    } on Object catch (error) {
      _set(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (!Validators.isValidOtp(otp)) {
      _set(_state.copyWith(error: 'Enter the 6 digit OTP.', clearInfo: true));
      return;
    }
    _set(_state.copyWith(loading: true, clearError: true, clearInfo: true));
    try {
      final identity = await authRepository.verifyOtp(mobile: state.mobile, otp: otp.trim(), verificationId: state.verificationId);
      final profile = await authRepository.loadProfile(identity.mobile);
      _set(_state.copyWith(
        loading: false,
        mobile: identity.mobile,
        uid: identity.uid,
        profile: profile,
        authStep: profile == null ? AuthStep.pinSetup : AuthStep.pinLogin,
        info: profile == null ? 'Create a secure PIN.' : 'Enter your saved PIN.',
      ));
    } on Object catch (error) {
      _set(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> submitPin(String pin, {required bool setup}) async {
    if (!Validators.isValidPin(pin)) {
      _set(_state.copyWith(error: 'PIN must be 4 to 8 digits.', clearInfo: true));
      return;
    }
    _set(_state.copyWith(loading: true, clearError: true, clearInfo: true));
    try {
      if (setup) {
        final profile = await authRepository.createOrUpdatePin(uid: state.uid, mobile: state.mobile, pin: pin.trim());
        _set(_state.copyWith(loading: false, profile: profile, authStep: AuthStep.role, info: 'PIN saved. Select role.'));
      } else {
        final valid = await authRepository.verifyPin(mobile: state.mobile, pin: pin.trim());
        if (!valid) {
          _set(_state.copyWith(loading: false, error: 'Wrong PIN.', clearInfo: true));
          return;
        }
        _set(_state.copyWith(loading: false, authStep: AuthStep.role, info: 'PIN verified. Select role.'));
      }
    } on Object catch (error) {
      _set(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> selectRole(AppRole role) async {
    if (role == AppRole.select) {
      _set(_state.copyWith(error: 'Please select a role.', clearInfo: true));
      return;
    }
    final now = DateTime.now();
    final session = AppSession(uid: state.uid, mobile: state.mobile, role: role, createdAt: now, lastActiveAt: now);
    await authRepository.saveSession(session);
    await authRepository.writeAuditLog(actorMobile: session.mobile, role: role, action: 'login', payload: <String, dynamic>{'createdAt': now.toIso8601String()});
    _set(_state.copyWith(authStep: AuthStep.app, session: session, pageIndex: 0, info: 'Logged in as ${role.label}.', clearError: true));
  }

  Future<void> logout({String reason = 'Logged out.'}) async {
    final oldSession = state.session;
    await authRepository.clearSession();
    if (oldSession != null) {
      await authRepository.writeAuditLog(actorMobile: oldSession.mobile, role: oldSession.role, action: 'logout', payload: <String, dynamic>{'reason': reason});
    }
    _set(AppState(firebaseStatus: state.firebaseStatus, authStep: AuthStep.login, info: reason));
  }

  Future<void> validateSession() async {
    final session = state.session;
    if (state.authStep != AuthStep.app || session == null) return;
    if (session.isExpired) await logout(reason: 'Session expired due to inactivity.');
  }

  Future<void> markActivity() async {
    final session = state.session;
    if (state.authStep != AuthStep.app || session == null) return;
    final updated = session.markActive();
    _state = state.copyWith(session: updated);
    final now = DateTime.now();
    if (now.difference(_lastSessionSave) > const Duration(seconds: 20)) {
      _lastSessionSave = now;
      await authRepository.saveSession(updated);
    }
  }

  void changePage(int index) {
    _set(_state.copyWith(pageIndex: index, clearError: true, clearInfo: true));
  }

  void backToLogin() => _set(_state.copyWith(authStep: AuthStep.login, clearError: true, clearInfo: true));

  void _set(AppState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _securityTimer?.cancel();
    super.dispose();
  }
}
