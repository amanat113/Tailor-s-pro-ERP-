import 'dart:convert';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.mobile,
    required this.pinSalt,
    required this.pinHash,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String mobile;
  final String pinSalt;
  final String pinHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? uid,
    String? mobile,
    String? pinSalt,
    String? pinHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      mobile: mobile ?? this.mobile,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'uid': uid,
        'mobile': mobile,
        'pinSalt': pinSalt,
        'pinHash': pinHash,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: (map['uid'] ?? '') as String,
      mobile: (map['mobile'] ?? '') as String,
      pinSalt: (map['pinSalt'] ?? '') as String,
      pinHash: (map['pinHash'] ?? '') as String,
      createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((map['updatedAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) {
    return UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
