import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/core/firebase/firebase_bootstrap.dart';
import 'app/core/storage/local_key_value_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseStatus = await FirebaseBootstrap.initialize();
  final localStore = LocalKeyValueStore();
  final authRepository = AuthRepository(
    firebaseStatus: firebaseStatus,
    localStore: localStore,
  );
  final authController = AuthController(repository: authRepository);
  await authController.restoreSession();

  runApp(TailorsErpApp(controller: authController));
}
