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
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    // Bug #22: these were hard casts (`as Timestamp`), so ONE malformed doc
    // threw during list mapping and permanently bricked the whole ward's
    // task stream. Parse defensively instead - a bad field degrades that one
    // card, never the list.
    return TaskModel(
      id: id,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      isCompleted: map['isCompleted'] == true,
      dueDate: _parseTimestamp(map['dueDate']) ?? DateTime.now(),
      patientId: map['patientId']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? '',
      assignedNurseId: map['assignedNurseId']?.toString() ?? '',
      assignedNurseName: map['assignedNurseName']?.toString() ?? 'Unknown',
      wardNumber: (map['wardNumber'] as num?)?.toInt() ?? 1,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      completedByNurseId: map['completedByNurseId']?.toString(),
      completedByNurseName: map['completedByNurseName']?.toString(),
      completedAt: _parseTimestamp(map['completedAt']),
    );
  }

  /// Tolerant timestamp parser: accepts Timestamp and ISO-8601 strings,
  /// returns null for anything else instead of throwing.
  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
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
