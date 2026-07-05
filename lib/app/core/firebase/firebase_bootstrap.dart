import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_environment.dart';

class FirebaseStatus {
  const FirebaseStatus({required this.enabled, this.message});

  final bool enabled;
  final String? message;
}

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<FirebaseStatus> initialize() async {
    if (!FirebaseEnvironment.isConfigured) {
      return const FirebaseStatus(
        enabled: false,
        message: 'Firebase config missing. Real OTP login is blocked until Firebase is configured.',
      );
    }

    try {
      await Firebase.initializeApp(options: FirebaseEnvironment.androidOptions);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      return const FirebaseStatus(enabled: true, message: 'Firebase connected.');
    } on Object catch (error) {
      return FirebaseStatus(
        enabled: false,
        message: 'Firebase failed to initialize: $error',
      );
    }
  }
}
