import 'package:cloud_firestore/cloud_firestore.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.specialization,
    required this.rates,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String specialization;
  final Map<String, num> rates;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'specialization': specialization,
        'rates': rates,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory StaffMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawRates = data['rates'];
    return StaffMember(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      specialization: '${data['specialization'] ?? ''}',
      rates: rawRates is Map
          ? rawRates.map((key, value) => MapEntry('$key', (value as num?) ?? 0))
          : <String, num>{},
      createdAt: _readDate(data['createdAt']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
