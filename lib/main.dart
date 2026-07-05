import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'data/auth_repository.dart';
import 'screens/auth_screens.dart';
import 'screens/main_shell.dart';
import 'services/local_store.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(authRepository: AuthRepository(localStore: const LocalStore()));
  runApp(TailorsErpApp(controller: controller));
  await controller.start();
}

class TailorsErpApp extends StatefulWidget {
  const TailorsErpApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<TailorsErpApp> createState() => _TailorsErpAppState();
}

class _TailorsErpAppState extends State<TailorsErpApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.validateSession();
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
            theme: ThemeData.light(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: AppColors.paper,
              colorScheme: const ColorScheme.light(
                primary: AppColors.navy,
                secondary: AppColors.bronze,
                surface: AppColors.card,
                onSurface: AppColors.ink,
                error: AppColors.red,
              ),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: false,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.ink,
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.bronze, width: 1.4)),
              ),
            ),
            home: _screen(widget.controller),
          ),
        );
      },
    );
  }

  Widget _screen(AppController controller) {
    switch (controller.state.authStep) {
      case AuthStep.booting:
        return const SplashScreen();
      case AuthStep.login:
        return LoginScreen(controller: controller);
      case AuthStep.otp:
        return OtpScreen(controller: controller);
      case AuthStep.pinSetup:
        return PinScreen(controller: controller, setup: true);
      case AuthStep.pinLogin:
        return PinScreen(controller: controller, setup: false);
      case AuthStep.role:
        return RoleScreen(controller: controller);
      case AuthStep.app:
        return MainShell(controller: controller);
    }
  }
}
