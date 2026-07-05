import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/pin_screen.dart';
import '../features/auth/presentation/role_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import 'theme/app_theme.dart';

class TailorsErpApp extends StatefulWidget {
  const TailorsErpApp({required this.controller, super.key});

  final AuthController controller;

  @override
  State<TailorsErpApp> createState() => _TailorsErpAppState();
}

class _TailorsErpAppState extends State<TailorsErpApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.startSecurityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.validateSessionPolicy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => widget.controller.markActivity(),
          onPointerMove: (_) => widget.controller.markActivity(),
          child: MaterialApp(
            title: "Tailor's ERP",
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: _screenFor(widget.controller),
          ),
        );
      },
    );
  }

  Widget _screenFor(AuthController controller) {
    switch (controller.state.step) {
      case AuthStep.booting:
        return const SplashScreen();
      case AuthStep.login:
        return LoginScreen(controller: controller);
      case AuthStep.otp:
        return OtpScreen(controller: controller);
      case AuthStep.pinSetup:
        return PinScreen(controller: controller, isSetup: true);
      case AuthStep.pinLogin:
        return PinScreen(controller: controller, isSetup: false);
      case AuthStep.role:
        return RoleScreen(controller: controller);
      case AuthStep.dashboard:
        return DashboardScreen(controller: controller);
    }
  }
}
