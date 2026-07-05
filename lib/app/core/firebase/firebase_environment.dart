import 'package:firebase_core/firebase_core.dart';

class FirebaseEnvironment {
  FirebaseEnvironment._();

  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String androidAppId =
      String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        androidAppId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        projectId.isNotEmpty &&
        storageBucket.isNotEmpty;
  }

  static FirebaseOptions get androidOptions {
    if (!isConfigured) {
      throw StateError('Firebase dart-define configuration is missing.');
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: androidAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }
}
