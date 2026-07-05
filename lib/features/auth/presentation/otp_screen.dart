import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../../shared/widgets/screen_frame.dart';
import 'auth_controller.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ScreenFrame(
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconButton(
              onPressed: widget.controller.goBackToLogin,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            const SizedBox(height: 12),
            const Text('Verify OTP', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('OTP sent to ${state.mobile}', style: const TextStyle(color: Color(0xFF697386))),
            const SizedBox(height: 22),
            MessageBanner(error: state.error, info: state.info),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                hintText: 'Enter 6 digit OTP',
                prefixIcon: Icon(Icons.verified_user_rounded),
              ),
              onSubmitted: (_) => widget.controller.verifyOtp(_otpController.text),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Verify OTP',
              loading: state.loading,
              icon: Icons.check_circle_rounded,
              onPressed: () => widget.controller.verifyOtp(_otpController.text),
            ),
          ],
        ),
      ),
    );
  }
}
