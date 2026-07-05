import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

class ShopSettings {
  const ShopSettings({
    required this.shopName,
    required this.address,
    required this.phone,
    required this.slipNote,
    required this.measurements,
    required this.stitchTypes,
  });

  final String shopName;
  final String address;
  final String phone;
  final String slipNote;
  final List<String> measurements;
  final List<String> stitchTypes;

  factory ShopSettings.defaults() {
    return const ShopSettings(
      shopName: "Tailor's ERP",
      address: '',
      phone: '',
      slipNote: 'Thank you for choosing us.',
      measurements: AppConstants.defaultMeasurements,
      stitchTypes: AppConstants.defaultStitchTypes,
    );
  }

  ShopSettings copyWith({
    String? shopName,
    String? address,
    String? phone,
    String? slipNote,
    List<String>? measurements,
    List<String>? stitchTypes,
  }) {
    return ShopSettings(
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      slipNote: slipNote ?? this.slipNote,
      measurements: measurements ?? this.measurements,
      stitchTypes: stitchTypes ?? this.stitchTypes,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'shopName': shopName,
        'address': address,
        'phone': phone,
        'slipNote': slipNote,
        'measurements': measurements,
        'stitchTypes': stitchTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ShopSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return ShopSettings.defaults();
    return ShopSettings(
      shopName: '${data['shopName'] ?? "Tailor's ERP"}',
      address: '${data['address'] ?? ''}',
      phone: '${data['phone'] ?? ''}',
      slipNote: '${data['slipNote'] ?? 'Thank you for choosing us.'}',
      measurements: (data['measurements'] as List?)?.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList() ?? AppConstants.defaultMeasurements,
      stitchTypes: (data['stitchTypes'] as List?)?.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList() ?? AppConstants.defaultStitchTypes,
    );
  }
}
