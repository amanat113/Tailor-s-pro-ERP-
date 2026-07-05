import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shop_settings.dart';
import 'firestore_paths.dart';

class SettingsRepository {
  Stream<ShopSettings> watchSettings() {
    return FirestorePaths.settings().snapshots().map((doc) => ShopSettings.fromDoc(doc));
  }

  Future<ShopSettings> loadSettings() async {
    final doc = await FirestorePaths.settings().get();
    return ShopSettings.fromDoc(doc);
  }

  Future<void> saveSettings(ShopSettings settings) async {
    await FirestorePaths.settings().set(settings.toMap(), SetOptions(merge: true));
  }

  Future<void> resetAllData() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final collection in <CollectionReference<Map<String, dynamic>>>[
      FirestorePaths.orders(),
      FirestorePaths.staff(),
      FirestorePaths.staffLedger(),
      FirestorePaths.deliveryLedger(),
      FirestorePaths.auditLogs(),
    ]) {
      final docs = await collection.limit(400).get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }
}
