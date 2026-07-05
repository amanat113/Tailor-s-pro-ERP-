import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryEntry {
  const DeliveryEntry({
    required this.id,
    required this.orderId,
    required this.slipNo,
    required this.customerName,
    required this.mobile,
    required this.deliveredQty,
    required this.paidNow,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String slipNo;
  final String customerName;
  final String mobile;
  final int deliveredQty;
  final num paidNow;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'orderId': orderId,
        'slipNo': slipNo,
        'customerName': customerName,
        'mobile': mobile,
        'deliveredQty': deliveredQty,
        'paidNow': paidNow,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory DeliveryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DeliveryEntry(
      id: doc.id,
      orderId: '${data['orderId'] ?? ''}',
      slipNo: '${data['slipNo'] ?? ''}',
      customerName: '${data['customerName'] ?? ''}',
      mobile: '${data['mobile'] ?? ''}',
      deliveredQty: (data['deliveredQty'] as num?)?.toInt() ?? 0,
      paidNow: (data['paidNow'] as num?) ?? 0,
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
