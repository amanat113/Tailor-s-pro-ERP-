import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/core/firebase/firebase_bootstrap.dart';
import '../domain/order_status.dart';
import '../domain/tailor_order.dart';

class CreateOrderInput {
  const CreateOrderInput({
    required this.slipNumber,
    required this.customerName,
    required this.mobile,
    required this.clothQty,
    required this.totalBill,
    required this.advancePaid,
  });

  final String slipNumber;
  final String customerName;
  final String mobile;
  final int clothQty;
  final double totalBill;
  final double advancePaid;
}

class UpdateOrderInput {
  const UpdateOrderInput({
    required this.id,
    required this.customerName,
    required this.mobile,
    required this.clothQty,
    required this.totalBill,
    required this.advancePaid,
    required this.status,
  });

  final String id;
  final String customerName;
  final String mobile;
  final int clothQty;
  final double totalBill;
  final double advancePaid;
  final OrderStatus status;
}

class OrderRepository {
  OrderRepository({required this.firebaseStatus, this.shopId = 'default_shop'});

  final FirebaseStatus firebaseStatus;
  final String shopId;

  bool get isCloudEnabled => firebaseStatus.enabled;

  CollectionReference<Map<String, dynamic>> get _orders => FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('orders');

  Stream<List<TailorOrder>> watchOrders() {
    if (!isCloudEnabled) return Stream<List<TailorOrder>>.value(const <TailorOrder>[]);
    return _orders.snapshots().map((snapshot) {
      final orders = snapshot.docs.map(TailorOrder.fromFirestore).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Stream<List<TailorOrder>> watchRecentOrders({int limit = 10}) {
    return watchOrders().map((orders) => orders.take(limit).toList());
  }

  Stream<OrderDashboardStats> watchStats() {
    return watchOrders().map((orders) {
      final active = orders.where((order) => order.status.isActive).toList();
      return OrderDashboardStats(
        totalOrders: orders.length,
        activeOrders: active.length,
        totalActiveClothes: active.fold<int>(0, (sum, order) => sum + order.activeClothes),
        pendingClothes: active.fold<int>(0, (sum, order) => sum + order.pendingQty),
        totalDue: orders.fold<double>(0, (sum, order) => sum + order.dueAmount),
        totalRevenue: orders.fold<double>(0, (sum, order) => sum + (order.totalBill - order.dueAmount)),
      );
    });
  }

  Future<void> createOrder(CreateOrderInput input) async {
    _ensureCloud();
    final slip = input.slipNumber.trim();
    if (slip.isEmpty) throw StateError('Slip number is required.');
    if (input.customerName.trim().isEmpty) throw StateError('Customer name is required.');
    if (input.mobile.trim().length < 10) throw StateError('Valid mobile number is required.');
    if (input.clothQty <= 0) throw StateError('Cloth quantity must be greater than zero.');
    if (input.totalBill < 0 || input.advancePaid < 0) throw StateError('Amount cannot be negative.');

    final duplicate = await _orders.where('slipNumber', isEqualTo: slip).limit(1).get();
    if (duplicate.docs.isNotEmpty) throw StateError('Slip number already exists.');

    final now = DateTime.now();
    final due = (input.totalBill - input.advancePaid).clamp(0, double.infinity).toDouble();
    final doc = _orders.doc();
    final order = TailorOrder(
      id: doc.id,
      slipNumber: slip,
      customerName: input.customerName.trim(),
      mobile: input.mobile.trim(),
      clothQty: input.clothQty,
      pendingQty: input.clothQty,
      deliveredQty: 0,
      totalBill: input.totalBill,
      advancePaid: input.advancePaid,
      dueAmount: due,
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await doc.set(order.toFirestoreMap());
  }

  Future<void> updateOrder(UpdateOrderInput input) async {
    _ensureCloud();
    if (input.id.trim().isEmpty) throw StateError('Order id is missing.');
    if (input.customerName.trim().isEmpty) throw StateError('Customer name is required.');
    if (input.mobile.trim().length < 10) throw StateError('Valid mobile number is required.');
    if (input.clothQty <= 0) throw StateError('Cloth quantity must be greater than zero.');
    if (input.totalBill < 0 || input.advancePaid < 0) throw StateError('Amount cannot be negative.');

    final due = (input.totalBill - input.advancePaid).clamp(0, double.infinity).toDouble();
    await _orders.doc(input.id).set(<String, dynamic>{
      'customerName': input.customerName.trim(),
      'mobile': input.mobile.trim(),
      'clothQty': input.clothQty,
      'totalBill': input.totalBill,
      'advancePaid': input.advancePaid,
      'dueAmount': due,
      'status': input.status.storageValue,
      'pendingQty': input.status == OrderStatus.delivered ? 0 : FieldValue.increment(0),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _ensureCloud() {
    if (!isCloudEnabled) {
      throw StateError('Cloud Firestore is not connected. Configure Firebase first.');
    }
  }
}
