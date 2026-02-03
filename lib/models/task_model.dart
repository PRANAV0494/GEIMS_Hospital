import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime dueDate;
  final String patientId;
  final String patientName;
  final String assignedNurseId; // Who created it
  final String assignedNurseName; // Name of creator
  final int wardNumber;
  final DateTime createdAt;
  
  // Completion details
  final String? completedByNurseId;
  final String? completedByNurseName;
  final DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.dueDate,
    required this.patientId,
    required this.patientName,
    required this.assignedNurseId,
    required this.assignedNurseName,
    required this.wardNumber,
    required this.createdAt,
    this.completedByNurseId,
    this.completedByNurseName,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': Timestamp.fromDate(dueDate),
      'patientId': patientId,
      'patientName': patientName,
      'assignedNurseId': assignedNurseId,
      'assignedNurseName': assignedNurseName,
      'wardNumber': wardNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedByNurseId': completedByNurseId,
      'completedByNurseName': completedByNurseName,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      assignedNurseId: map['assignedNurseId'] ?? '',
      assignedNurseName: map['assignedNurseName'] ?? 'Unknown',
      wardNumber: map['wardNumber'] ?? 1,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedByNurseId: map['completedByNurseId'],
      completedByNurseName: map['completedByNurseName'],
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    return TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    String? patientId,
    String? patientName,
    String? assignedNurseId,
    String? assignedNurseName,
    int? wardNumber,
    DateTime? createdAt,
    String? completedByNurseId,
    String? completedByNurseName,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      assignedNurseId: assignedNurseId ?? this.assignedNurseId,
      assignedNurseName: assignedNurseName ?? this.assignedNurseName,
      wardNumber: wardNumber ?? this.wardNumber,
      createdAt: createdAt ?? this.createdAt,
      completedByNurseId: completedByNurseId ?? this.completedByNurseId,
      completedByNurseName: completedByNurseName ?? this.completedByNurseName,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
