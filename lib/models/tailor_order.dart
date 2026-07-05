import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_status.dart';

class TailorOrder {
  const TailorOrder({
    required this.id,
    required this.slipNo,
    required this.customerName,
    required this.mobile,
    required this.clothQty,
    required this.measurements,
    required this.totalBill,
    required this.advancePaid,
    required this.dueAmount,
    required this.designUrl,
    required this.itemStatuses,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.slipPdfUrl = '',
  });

  final String id;
  final String slipNo;
  final String customerName;
  final String mobile;
  final int clothQty;
  final Map<String, String> measurements;
  final num totalBill;
  final num advancePaid;
  final num dueAmount;
  final String designUrl;
  final List<ClothStatus> itemStatuses;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String slipPdfUrl;

  int get deliveredQty => itemStatuses.where((item) => item == ClothStatus.delivered).length;
  int get readyQty => itemStatuses.where((item) => item == ClothStatus.ready).length;
  int get cuttingQty => itemStatuses.where((item) => item == ClothStatus.cutting).length;
  int get pendingQty => itemStatuses.where((item) => item == ClothStatus.pending).length;
  int get activeQty => itemStatuses.where((item) => item != ClothStatus.delivered).length;
  bool get allCuttingComplete => itemStatuses.isNotEmpty && itemStatuses.every((item) => item != ClothStatus.pending);
  bool get allReady => itemStatuses.isNotEmpty && itemStatuses.every((item) => item == ClothStatus.ready || item == ClothStatus.delivered);
  bool get allDelivered => itemStatuses.isNotEmpty && itemStatuses.every((item) => item == ClothStatus.delivered);

  TailorOrder copyWith({
    String? id,
    String? slipNo,
    String? customerName,
    String? mobile,
    int? clothQty,
    Map<String, String>? measurements,
    num? totalBill,
    num? advancePaid,
    num? dueAmount,
    String? designUrl,
    List<ClothStatus>? itemStatuses,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? slipPdfUrl,
  }) {
    return TailorOrder(
      id: id ?? this.id,
      slipNo: slipNo ?? this.slipNo,
      customerName: customerName ?? this.customerName,
      mobile: mobile ?? this.mobile,
      clothQty: clothQty ?? this.clothQty,
      measurements: measurements ?? this.measurements,
      totalBill: totalBill ?? this.totalBill,
      advancePaid: advancePaid ?? this.advancePaid,
      dueAmount: dueAmount ?? this.dueAmount,
      designUrl: designUrl ?? this.designUrl,
      itemStatuses: itemStatuses ?? this.itemStatuses,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      slipPdfUrl: slipPdfUrl ?? this.slipPdfUrl,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'slipNo': slipNo,
        'customerName': customerName,
        'mobile': mobile,
        'clothQty': clothQty,
        'measurements': measurements,
        'totalBill': totalBill,
        'advancePaid': advancePaid,
        'dueAmount': dueAmount,
        'designUrl': designUrl,
        'itemStatuses': itemStatuses.map((item) => item.value).toList(),
        'status': status.value,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'slipPdfUrl': slipPdfUrl,
      };

  factory TailorOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawMeasurements = data['measurements'];
    final rawStatuses = data['itemStatuses'];
    return TailorOrder(
      id: doc.id,
      slipNo: '${data['slipNo'] ?? ''}',
      customerName: '${data['customerName'] ?? ''}',
      mobile: '${data['mobile'] ?? ''}',
      clothQty: (data['clothQty'] as num?)?.toInt() ?? 0,
      measurements: rawMeasurements is Map
          ? rawMeasurements.map((key, value) => MapEntry('$key', '$value'))
          : <String, String>{},
      totalBill: (data['totalBill'] as num?) ?? 0,
      advancePaid: (data['advancePaid'] as num?) ?? 0,
      dueAmount: (data['dueAmount'] as num?) ?? 0,
      designUrl: '${data['designUrl'] ?? ''}',
      itemStatuses: rawStatuses is List
          ? rawStatuses.map((item) => ClothStatusX.fromValue('$item')).toList()
          : <ClothStatus>[],
      status: OrderStatusX.fromValue('${data['status'] ?? 'pending'}'),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      slipPdfUrl: '${data['slipPdfUrl'] ?? ''}',
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
