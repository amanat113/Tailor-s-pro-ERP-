import 'package:flutter/material.dart';

import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/screen_frame.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenFrame(
      child: SizedBox(
        height: 620,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AppLogo(),
            SizedBox(height: 22),
            Text(
              "Tailor's ERP",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text('Secure tailoring management system'),
            SizedBox(height: 28),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
