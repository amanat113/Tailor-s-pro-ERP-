import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/app_constants.dart';
import '../models/app_role.dart';
import '../widgets/forms.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.checkroom_rounded, size: 72, color: AppColors.bronze),
            SizedBox(height: 16),
            Text(AppConstants.appName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            SizedBox(height: 14),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobile = TextEditingController();

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 34),
              const Icon(Icons.checkroom_rounded, size: 62, color: AppColors.bronze),
              const SizedBox(height: 18),
              const Text(AppConstants.appName, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Professional Tailoring & Garment Management', style: TextStyle(color: AppColors.muted, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 26),
              MessageBanner(error: state.error, info: state.info),
              AppCard(
                child: Column(
                  children: <Widget>[
                    AppTextField(controller: _mobile, label: 'Mobile Number', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                    PrimaryButton(label: 'Send OTP', loading: state.loading, icon: Icons.sms_rounded, onPressed: () => widget.controller.sendOtp(_mobile.text)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Real Firebase Mobile OTP is required. No demo login is used.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(onPressed: widget.controller.backToLogin, icon: const Icon(Icons.arrow_back_rounded)),
              const SizedBox(height: 16),
              const Text('Verify OTP', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('OTP sent to ${state.mobile}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              MessageBanner(error: state.error, info: state.info),
              AppCard(
                child: Column(
                  children: <Widget>[
                    AppTextField(controller: _otp, label: 'OTP Code', icon: Icons.verified_user_rounded, keyboardType: TextInputType.number),
                    PrimaryButton(label: 'Verify OTP', loading: state.loading, icon: Icons.check_circle_rounded, onPressed: () => widget.controller.verifyOtp(_otp.text)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinScreen extends StatefulWidget {
  const PinScreen({required this.controller, required this.setup, super.key});
  final AppController controller;
  final bool setup;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final TextEditingController _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 40),
              Icon(widget.setup ? Icons.lock_reset_rounded : Icons.lock_rounded, size: 58, color: AppColors.bronze),
              const SizedBox(height: 18),
              Text(widget.setup ? 'Create Secure PIN' : 'Enter PIN', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(widget.setup ? 'Create a 4 to 8 digit PIN for future login.' : 'Use your saved PIN to continue.', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              MessageBanner(error: state.error, info: state.info),
              AppCard(
                child: Column(
                  children: <Widget>[
                    AppTextField(controller: _pin, label: 'PIN', icon: Icons.pin_rounded, keyboardType: TextInputType.number),
                    PrimaryButton(label: widget.setup ? 'Save PIN' : 'Continue', loading: state.loading, icon: Icons.login_rounded, onPressed: () => widget.controller.submitPin(_pin.text, setup: widget.setup)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleScreen extends StatefulWidget {
  const RoleScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  AppRole _role = AppRole.select;

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 40),
              const Icon(Icons.admin_panel_settings_rounded, size: 58, color: AppColors.bronze),
              const SizedBox(height: 18),
              const Text('Select Role', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Role controls permissions inside the app.', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              MessageBanner(error: state.error, info: state.info),
              AppCard(
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField<AppRole>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_rounded)),
                      items: AppRole.values.map((role) => DropdownMenuItem<AppRole>(value: role, child: Text(role.label))).toList(),
                      onChanged: (role) => setState(() => _role = role ?? AppRole.select),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(label: 'Open App', loading: state.loading, icon: Icons.dashboard_rounded, onPressed: () => widget.controller.selectRole(_role)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
