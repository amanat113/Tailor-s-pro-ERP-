import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_status.dart';

class TailorOrder {
  const TailorOrder({
    required this.id,
    required this.slipNumber,
    required this.customerName,
    required this.mobile,
    required this.clothQty,
    required this.pendingQty,
    required this.deliveredQty,
    required this.totalBill,
    required this.advancePaid,
    required this.dueAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String slipNumber;
  final String customerName;
  final String mobile;
  final int clothQty;
  final int pendingQty;
  final int deliveredQty;
  final double totalBill;
  final double advancePaid;
  final double dueAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get activeClothes => (clothQty - deliveredQty).clamp(0, 999999).toInt();

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'slipNumber': slipNumber,
      'customerName': customerName,
      'mobile': mobile,
      'clothQty': clothQty,
      'pendingQty': pendingQty,
      'deliveredQty': deliveredQty,
      'totalBill': totalBill,
      'advancePaid': advancePaid,
      'dueAmount': dueAmount,
      'status': status.storageValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TailorOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TailorOrder(
      id: doc.id,
      slipNumber: _string(data['slipNumber']),
      customerName: _string(data['customerName']),
      mobile: _string(data['mobile']),
      clothQty: _int(data['clothQty']),
      pendingQty: _int(data['pendingQty']),
      deliveredQty: _int(data['deliveredQty']),
      totalBill: _double(data['totalBill']),
      advancePaid: _double(data['advancePaid']),
      dueAmount: _double(data['dueAmount']),
      status: OrderStatusX.fromStorage(_string(data['status'])),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static String _string(Object? value) => value == null ? '' : value.toString();

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class OrderDashboardStats {
  const OrderDashboardStats({
    required this.totalOrders,
    required this.activeOrders,
    required this.totalActiveClothes,
    required this.pendingClothes,
    required this.totalDue,
    required this.totalRevenue,
  });

  final int totalOrders;
  final int activeOrders;
  final int totalActiveClothes;
  final int pendingClothes;
  final double totalDue;
  final double totalRevenue;
}
