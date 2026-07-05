import 'package:flutter/material.dart';

import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../../shared/widgets/screen_frame.dart';
import '../domain/app_role.dart';
import 'auth_controller.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({required this.controller, super.key});

  final AuthController controller;

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  AppRole _selectedRole = AppRole.select;

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ScreenFrame(
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.admin_panel_settings_rounded, size: 52, color: Color(0xFFC69A5B)),
            const SizedBox(height: 18),
            const Text('Select Role', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Role controls permissions inside the app.',
              style: TextStyle(color: Color(0xFF697386)),
            ),
            const SizedBox(height: 22),
            MessageBanner(error: state.error, info: state.info),
            DropdownButtonFormField<AppRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
              items: AppRole.values
                  .map(
                    (role) => DropdownMenuItem<AppRole>(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(),
              onChanged: (role) => setState(() => _selectedRole = role ?? AppRole.select),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Continue to Dashboard',
              loading: state.loading,
              icon: Icons.dashboard_customize_rounded,
              onPressed: () => widget.controller.selectRole(_selectedRole),
            ),
          ],
        ),
      ),
    );
  }
}
