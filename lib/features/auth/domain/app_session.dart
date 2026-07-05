import 'dart:convert';

import 'app_role.dart';

class AppSession {
  const AppSession({
    required this.uid,
    required this.mobile,
    required this.role,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String uid;
  final String mobile;
  final AppRole role;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  bool get isValidRole => role != AppRole.select;

  bool get isExpired {
    if (!isValidRole) return true;
    final inactive = DateTime.now().difference(lastActiveAt);
    return inactive > role.maxInactiveDuration;
  }

  AppSession markActive() {
    return copyWith(lastActiveAt: DateTime.now());
  }

  AppSession copyWith({
    String? uid,
    String? mobile,
    AppRole? role,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return AppSession(
      uid: uid ?? this.uid,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'uid': uid,
        'mobile': mobile,
        'role': role.storageValue,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  factory AppSession.fromMap(Map<String, dynamic> map) {
    return AppSession(
      uid: (map['uid'] ?? '') as String,
      mobile: (map['mobile'] ?? '') as String,
      role: AppRoleLabel.fromStorage((map['role'] ?? 'select') as String),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      lastActiveAt: DateTime.tryParse((map['lastActiveAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppSession.fromJson(String source) {
    return AppSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
