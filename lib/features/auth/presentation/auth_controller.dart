import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/core/utils/validators.dart';
import '../data/auth_repository.dart';
import '../domain/app_role.dart';
import '../domain/app_session.dart';
import '../domain/user_profile.dart';

enum AuthStep { booting, login, otp, pinSetup, pinLogin, role, dashboard }

class AuthViewState {
  const AuthViewState({
    required this.step,
    this.loading = false,
    this.error,
    this.info,
    this.mobile = '',
    this.verificationId = '',
    this.isFirebaseOtp = false,
    this.uid = '',
    this.profile,
    this.session,
  });

  final AuthStep step;
  final bool loading;
  final String? error;
  final String? info;
  final String mobile;
  final String verificationId;
  final bool isFirebaseOtp;
  final String uid;
  final UserProfile? profile;
  final AppSession? session;

  AuthViewState copyWith({
    AuthStep? step,
    bool? loading,
    String? error,
    String? info,
    String? mobile,
    String? verificationId,
    bool? isFirebaseOtp,
    String? uid,
    UserProfile? profile,
    AppSession? session,
    bool clearError = false,
    bool clearInfo = false,
    bool clearProfile = false,
    bool clearSession = false,
  }) {
    return AuthViewState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      info: clearInfo ? null : info ?? this.info,
      mobile: mobile ?? this.mobile,
      verificationId: verificationId ?? this.verificationId,
      isFirebaseOtp: isFirebaseOtp ?? this.isFirebaseOtp,
      uid: uid ?? this.uid,
      profile: clearProfile ? null : profile ?? this.profile,
      session: clearSession ? null : session ?? this.session,
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController({required this.repository});

  final AuthRepository repository;

  AuthViewState _state = const AuthViewState(step: AuthStep.booting);
  AuthViewState get state => _state;

  Timer? _securityTimer;
  DateTime _lastPersistedActivity = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> restoreSession() async {
    _setState(_state.copyWith(step: AuthStep.booting, loading: true, clearError: true));
    final session = await repository.loadSession();
    if (session != null && !session.isExpired) {
      _setState(
        _state.copyWith(
          step: AuthStep.dashboard,
          loading: false,
          mobile: session.mobile,
          uid: session.uid,
          session: session,
          info: 'Session restored.',
        ),
      );
      return;
    }

    if (session != null && session.isExpired) {
      await repository.clearSession();
    }
    _setState(
      const AuthViewState(
        step: AuthStep.login,
        info: 'Login required.',
      ),
    );
  }

  Future<void> sendOtp(String mobileInput) async {
    final mobile = Validators.normalizeIndianMobile(mobileInput);
    if (!Validators.isValidMobile(mobile)) {
      _setState(_state.copyWith(error: 'Enter a valid mobile number.', clearInfo: true));
      return;
    }

    _setState(_state.copyWith(loading: true, mobile: mobile, clearError: true, clearInfo: true));
    try {
      final result = await repository.requestOtp(
        mobile: mobile,
        codeSent: (verificationId) {
          _setState(
            _state.copyWith(
              step: AuthStep.otp,
              loading: false,
              mobile: mobile,
              verificationId: verificationId,
              info: 'OTP sent to $mobile.',
            ),
          );
        },
        failed: (error) {
          _setState(_state.copyWith(loading: false, error: error, clearInfo: true));
        },
      );
      _setState(
        _state.copyWith(
          loading: false,
          verificationId: result.verificationId,
          isFirebaseOtp: result.isFirebase,
        ),
      );
    } on Object catch (error) {
      _setState(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (!Validators.isValidOtp(otp)) {
      _setState(_state.copyWith(error: 'Enter the 6 digit OTP.', clearInfo: true));
      return;
    }
    _setState(_state.copyWith(loading: true, clearError: true, clearInfo: true));
    try {
      final identity = await repository.verifyOtp(
        mobile: state.mobile,
        otp: otp.trim(),
        verificationId: state.verificationId,
        isFirebaseOtp: state.isFirebaseOtp,
      );
      final profile = await repository.loadProfile(identity.mobile);
      _setState(
        _state.copyWith(
          loading: false,
          mobile: identity.mobile,
          uid: identity.uid,
          profile: profile,
          step: profile == null ? AuthStep.pinSetup : AuthStep.pinLogin,
          info: profile == null ? 'Create a secure PIN.' : 'Enter your PIN.',
        ),
      );
    } on Object catch (error) {
      _setState(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> submitPin(String pin, {required bool isSetup}) async {
    if (!Validators.isValidPin(pin)) {
      _setState(_state.copyWith(error: 'PIN must be 4 to 8 digits.', clearInfo: true));
      return;
    }
    _setState(_state.copyWith(loading: true, clearError: true, clearInfo: true));
    try {
      if (isSetup) {
        final profile = await repository.createOrUpdatePin(
          uid: state.uid,
          mobile: state.mobile,
          pin: pin.trim(),
        );
        _setState(
          _state.copyWith(
            loading: false,
            profile: profile,
            step: AuthStep.role,
            info: 'PIN saved securely. Select your role.',
          ),
        );
      } else {
        final isValid = await repository.verifyPin(mobile: state.mobile, pin: pin.trim());
        if (!isValid) {
          _setState(_state.copyWith(loading: false, error: 'Wrong PIN.', clearInfo: true));
          return;
        }
        _setState(
          _state.copyWith(
            loading: false,
            step: AuthStep.role,
            info: 'PIN verified. Select your role.',
          ),
        );
      }
    } on Object catch (error) {
      _setState(_state.copyWith(loading: false, error: '$error', clearInfo: true));
    }
  }

  Future<void> selectRole(AppRole role) async {
    if (role == AppRole.select) {
      _setState(_state.copyWith(error: 'Please select a role.', clearInfo: true));
      return;
    }
    final now = DateTime.now();
    final session = AppSession(
      uid: state.uid.isNotEmpty ? state.uid : 'local_${state.mobile}',
      mobile: state.mobile,
      role: role,
      createdAt: now,
      lastActiveAt: now,
    );
    await repository.saveSession(session);
    await repository.writeAuditLog(
      actorMobile: state.mobile,
      role: role,
      action: 'login',
      payload: <String, dynamic>{'sessionCreatedAt': now.toIso8601String()},
    );
    _setState(
      _state.copyWith(
        step: AuthStep.dashboard,
        session: session,
        info: 'Logged in as ${role.label}.',
        clearError: true,
      ),
    );
  }

  Future<void> logout({String? reason}) async {
    final oldSession = state.session;
    await repository.clearSession();
    if (oldSession != null) {
      await repository.writeAuditLog(
        actorMobile: oldSession.mobile,
        role: oldSession.role,
        action: 'logout',
        payload: <String, dynamic>{'reason': reason ?? 'manual'},
      );
    }
    _setState(
      AuthViewState(
        step: AuthStep.login,
        info: reason ?? 'Logged out.',
      ),
    );
  }

  void startSecurityTimer() {
    _securityTimer?.cancel();
    _securityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      validateSessionPolicy();
    });
  }

  Future<void> validateSessionPolicy() async {
    final session = state.session;
    if (state.step != AuthStep.dashboard || session == null) return;
    if (session.isExpired) {
      await logout(reason: 'Session expired due to inactivity.');
    }
  }

  Future<void> markActivity() async {
    final session = state.session;
    if (state.step != AuthStep.dashboard || session == null) return;
    final updated = session.markActive();
    _state = state.copyWith(session: updated);
    final now = DateTime.now();
    if (now.difference(_lastPersistedActivity) > const Duration(seconds: 20)) {
      _lastPersistedActivity = now;
      await repository.saveSession(updated);
    }
  }

  void goBackToLogin() {
    _setState(const AuthViewState(step: AuthStep.login));
  }

  void _setState(AuthViewState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _securityTimer?.cancel();
    super.dispose();
  }
}
