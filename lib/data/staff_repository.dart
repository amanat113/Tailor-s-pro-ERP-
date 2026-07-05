import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/staff_ledger_entry.dart';
import '../models/staff_member.dart';
import 'firestore_paths.dart';

class StaffSummary {
  const StaffSummary({required this.daysWorked, required this.totalQty, required this.totalEarned, required this.totalPaid});

  final int daysWorked;
  final int totalQty;
  final num totalEarned;
  final num totalPaid;
  num get balance => totalEarned - totalPaid;
}

class StaffRepository {
  Stream<List<StaffMember>> watchStaff() {
    return FirestorePaths.staff().orderBy('createdAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(StaffMember.fromDoc).toList());
  }

  Stream<List<StaffLedgerEntry>> watchLedger({String? staffId}) {
    return FirestorePaths.staffLedger().orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      final entries = snapshot.docs.map(StaffLedgerEntry.fromDoc).toList();
      if (staffId == null || staffId.isEmpty) return entries;
      return entries.where((entry) => entry.staffId == staffId).toList();
    });
  }

  Future<void> saveStaff({required String name, required String specialization, required Map<String, num> rates}) async {
    if (name.trim().isEmpty) throw StateError('Staff name is required.');
    if (rates.isEmpty) throw StateError('At least one piece rate is required.');
    await FirestorePaths.staff().add(StaffMember(id: '', name: name.trim(), specialization: specialization.trim(), rates: rates, createdAt: DateTime.now()).toMap());
  }

  Future<void> addLedger({required StaffMember staff, required String stitchType, required num rate, required int qty, required num paid, required DateTime workDate}) async {
    if (qty <= 0) throw StateError('Quantity must be greater than zero.');
    final earning = rate * qty;
    await FirestorePaths.staffLedger().add(StaffLedgerEntry(
      id: '',
      staffId: staff.id,
      staffName: staff.name,
      stitchType: stitchType,
      rate: rate,
      qty: qty,
      earning: earning,
      paid: paid,
      workDate: workDate,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<StaffSummary> summary(String staffId) async {
    final docs = await FirestorePaths.staffLedger().where('staffId', isEqualTo: staffId).get();
    final entries = docs.docs.map(StaffLedgerEntry.fromDoc).toList();
    final dates = entries.map((entry) => DateTime(entry.workDate.year, entry.workDate.month, entry.workDate.day).toIso8601String()).toSet();
    return StaffSummary(
      daysWorked: dates.length,
      totalQty: entries.fold<int>(0, (sum, entry) => sum + entry.qty),
      totalEarned: entries.fold<num>(0, (sum, entry) => sum + entry.earning),
      totalPaid: entries.fold<num>(0, (sum, entry) => sum + entry.paid),
    );
  }
}
