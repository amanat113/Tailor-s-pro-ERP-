import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

class FirestorePaths {
  FirestorePaths._();

  static DocumentReference<Map<String, dynamic>> shop() => FirebaseFirestore.instance.collection('shops').doc(AppConstants.shopId);
  static CollectionReference<Map<String, dynamic>> users() => shop().collection('users');
  static CollectionReference<Map<String, dynamic>> orders() => shop().collection('orders');
  static CollectionReference<Map<String, dynamic>> staff() => shop().collection('staff');
  static CollectionReference<Map<String, dynamic>> staffLedger() => shop().collection('staffLedger');
  static CollectionReference<Map<String, dynamic>> deliveryLedger() => shop().collection('deliveryLedger');
  static CollectionReference<Map<String, dynamic>> auditLogs() => shop().collection('auditLogs');
  static DocumentReference<Map<String, dynamic>> settings() => shop().collection('settings').doc('shop');
}
