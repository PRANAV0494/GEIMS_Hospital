import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String employeeId;
  final String role; // 'nurse' or 'doctor'
  final String? assignedWard;
  final String? profileImage;
  final String? specialization; // For doctors
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    this.assignedWard,
    this.profileImage,
    this.specialization,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'employeeId': employeeId,
      'role': role,
      'assignedWard': assignedWard,
      'profileImage': profileImage,
      'specialization': specialization,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      employeeId: map['employeeId'] ?? '',
      role: map['role'] ?? '',
      assignedWard: map['assignedWard'],
      profileImage: map['profileImage'],
      specialization: map['specialization'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap({...data, 'id': doc.id});
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? employeeId,
    String? role,
    String? assignedWard,
    String? profileImage,
    String? specialization,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      assignedWard: assignedWard ?? this.assignedWard,
      profileImage: profileImage ?? this.profileImage,
      specialization: specialization ?? this.specialization,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  bool get isNurse => role == 'nurse';
  bool get isDoctor => role == 'doctor';
  bool get isAdmin => role == 'admin';
}
