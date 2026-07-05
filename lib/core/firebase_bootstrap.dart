import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseStatus {
  const FirebaseStatus({required this.enabled, this.message});

  final bool enabled;
  final String? message;
}

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<FirebaseStatus> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      return const FirebaseStatus(enabled: true, message: 'Firebase connected');
    } on Object catch (error) {
      return FirebaseStatus(
        enabled: false,
        message: 'Firebase setup failed. Check google-services.json and Android package com.tailors.erp. Error: $error',
      );
    }
  }
}
