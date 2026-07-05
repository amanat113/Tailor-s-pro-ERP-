import 'package:cloud_firestore/cloud_firestore.dart';

class StaffLedgerEntry {
  const StaffLedgerEntry({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.stitchType,
    required this.rate,
    required this.qty,
    required this.earning,
    required this.paid,
    required this.workDate,
    required this.createdAt,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String stitchType;
  final num rate;
  final int qty;
  final num earning;
  final num paid;
  final DateTime workDate;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'staffId': staffId,
        'staffName': staffName,
        'stitchType': stitchType,
        'rate': rate,
        'qty': qty,
        'earning': earning,
        'paid': paid,
        'workDate': Timestamp.fromDate(workDate),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory StaffLedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return StaffLedgerEntry(
      id: doc.id,
      staffId: '${data['staffId'] ?? ''}',
      staffName: '${data['staffName'] ?? ''}',
      stitchType: '${data['stitchType'] ?? ''}',
      rate: (data['rate'] as num?) ?? 0,
      qty: (data['qty'] as num?)?.toInt() ?? 0,
      earning: (data['earning'] as num?) ?? 0,
      paid: (data['paid'] as num?) ?? 0,
      workDate: _readDate(data['workDate']),
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
