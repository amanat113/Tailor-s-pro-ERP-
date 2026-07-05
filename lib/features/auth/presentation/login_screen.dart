import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../../shared/widgets/screen_frame.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppLogo(),
                const SizedBox(height: 28),
                const Text(
                  "Tailor's ERP",
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.05),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Professional Tailoring & Garment Management',
                  style: TextStyle(fontSize: 16, color: Color(0xFF697386)),
                ),
                const SizedBox(height: 24),
                MessageBanner(error: state.error, info: state.info),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '10 digit mobile number',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  onSubmitted: (_) => widget.controller.sendOtp(_mobileController.text),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Send OTP Securely',
                  loading: state.loading,
                  icon: Icons.sms_rounded,
                  onPressed: () => widget.controller.sendOtp(_mobileController.text),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Real Firebase Mobile OTP is required. Demo login is disabled.',
                  style: TextStyle(color: Color(0xFF697386), height: 1.45, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
