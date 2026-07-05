import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order_status.dart';
import '../models/tailor_order.dart';
import 'firestore_paths.dart';

class OrderRepository {
  Stream<List<TailorOrder>> watchOrders({int limit = 100}) {
    return FirestorePaths.orders()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TailorOrder.fromDoc).toList());
  }

  Future<TailorOrder?> findBySlip(String slipNo) async {
    final query = await FirestorePaths.orders().where('slipNo', isEqualTo: slipNo.trim()).limit(1).get();
    if (query.docs.isEmpty) return null;
    return TailorOrder.fromDoc(query.docs.first);
  }

  Future<TailorOrder?> findByMobile(String mobile) async {
    final query = await FirestorePaths.orders().where('mobile', isEqualTo: mobile.trim()).orderBy('createdAt', descending: true).limit(1).get();
    if (query.docs.isEmpty) return null;
    return TailorOrder.fromDoc(query.docs.first);
  }

  Future<void> createOrder(TailorOrder order) async {
    final duplicate = await findBySlip(order.slipNo);
    if (duplicate != null) throw StateError('Slip number already exists.');
    await FirestorePaths.orders().add(order.toMap());
  }

  Future<void> updateOrder(TailorOrder order) async {
    await FirestorePaths.orders().doc(order.id).set(order.copyWith(updatedAt: DateTime.now()).toMap(), SetOptions(merge: true));
  }

  Future<void> updateSlipPdfUrl({required String orderId, required String url}) async {
    await FirestorePaths.orders().doc(orderId).set(<String, dynamic>{
      'slipPdfUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> updateClothStatus({required TailorOrder order, required int index, required ClothStatus status}) async {
    if (index < 0 || index >= order.itemStatuses.length) return null;
    final beforeAllCutting = order.allCuttingComplete;
    final beforeAllReady = order.allReady;
    final statuses = List<ClothStatus>.from(order.itemStatuses);
    statuses[index] = status;
    final updated = _deriveStatus(order.copyWith(itemStatuses: statuses, updatedAt: DateTime.now()));
    await updateOrder(updated);
    if (!beforeAllCutting && updated.allCuttingComplete) return 'cutting';
    if (!beforeAllReady && updated.allReady) return 'ready';
    return null;
  }

  Future<void> deliverReadyItems({required TailorOrder order, required int qty, required num paidNow}) async {
    if (qty <= 0) throw StateError('Delivery quantity must be greater than zero.');
    if (qty > order.readyQty) throw StateError('Delivery quantity cannot exceed ready clothes.');
    final statuses = List<ClothStatus>.from(order.itemStatuses);
    var remaining = qty;
    for (var i = 0; i < statuses.length; i++) {
      if (remaining == 0) break;
      if (statuses[i] == ClothStatus.ready) {
        statuses[i] = ClothStatus.delivered;
        remaining--;
      }
    }
    final newDue = (order.dueAmount - paidNow).clamp(0, double.infinity);
    final updated = _deriveStatus(order.copyWith(
      itemStatuses: statuses,
      dueAmount: newDue,
      advancePaid: order.advancePaid + paidNow,
      updatedAt: DateTime.now(),
    ));
    final batch = FirebaseFirestore.instance.batch();
    batch.set(FirestorePaths.orders().doc(order.id), updated.toMap(), SetOptions(merge: true));
    batch.set(FirestorePaths.deliveryLedger().doc(), <String, dynamic>{
      'orderId': order.id,
      'slipNo': order.slipNo,
      'customerName': order.customerName,
      'mobile': order.mobile,
      'deliveredQty': qty,
      'paidNow': paidNow,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  TailorOrder _deriveStatus(TailorOrder order) {
    if (order.allDelivered) return order.copyWith(status: OrderStatus.delivered);
    if (order.allReady) return order.copyWith(status: OrderStatus.ready);
    if (order.cuttingQty > 0 || order.readyQty > 0) return order.copyWith(status: OrderStatus.cutting);
    return order.copyWith(status: OrderStatus.pending);
  }
}
