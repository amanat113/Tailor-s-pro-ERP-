import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../../shared/widgets/screen_frame.dart';
import 'auth_controller.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({required this.controller, required this.isSetup, super.key});

  final AuthController controller;
  final bool isSetup;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final title = widget.isSetup ? 'Create Secure PIN' : 'Enter PIN';
    final button = widget.isSetup ? 'Save PIN' : 'Unlock App';

    return ScreenFrame(
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.lock_rounded, size: 48, color: Color(0xFF38BDF8)),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              widget.isSetup
                  ? 'Create a 4 to 8 digit PIN for this mobile number.'
                  : 'Use your saved PIN to continue.',
              style: const TextStyle(color: Color(0xFFB9C6D8)),
            ),
            const SizedBox(height: 22),
            MessageBanner(error: state.error, info: state.info),
            TextField(
              controller: _pinController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: '4 to 8 digits',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
              onSubmitted: (_) => widget.controller.submitPin(_pinController.text, isSetup: widget.isSetup),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: button,
              loading: state.loading,
              icon: Icons.lock_open_rounded,
              onPressed: () => widget.controller.submitPin(_pinController.text, isSetup: widget.isSetup),
            ),
          ],
        ),
      ),
    );
  }
}
