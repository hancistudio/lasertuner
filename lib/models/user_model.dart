import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role; // 'user' veya 'researcher'
  final int reputation;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.role = 'user',
    this.reputation = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'reputation': reputation,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // createdAt'i parse ederken hem Timestamp hem String formatını destekle
    DateTime parsedCreatedAt;

    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(map['createdAt']);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      reputation: map['reputation'] ?? 0,
      createdAt: parsedCreatedAt,
    );
  }

  // copyWith metodu - kullanıcı bilgilerini güncellemek için
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    int? reputation,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      reputation: reputation ?? this.reputation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
