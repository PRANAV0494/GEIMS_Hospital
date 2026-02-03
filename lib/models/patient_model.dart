import 'package:cloud_firestore/cloud_firestore.dart';

class PatientModel {
  final String id;
  final String? patientCode; // Human-readable ID: GEIMS0001, GEIMS0002, etc.
  final String name;
  final int age;
  final String gender;
  final String diagnosisSummary;
  final int wardNumber;
  final int bedNumber;
  final DateTime admissionDate;
  final String attendingDoctorId;
  final String attendingDoctorName;
  final List<String> allergies;
  final String? specialNotes;
  final bool isCritical;
  final String status; // 'stable', 'critical', 'pending'
  final String? assignedNurseId;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientModel({
    required this.id,
    this.patientCode,
    required this.name,
    required this.age,
    required this.gender,
    required this.diagnosisSummary,
    required this.wardNumber,
    required this.bedNumber,
    required this.admissionDate,
    required this.attendingDoctorId,
    required this.attendingDoctorName,
    this.allergies = const [],
    this.specialNotes,
    this.isCritical = false,
    this.status = 'stable',
    this.assignedNurseId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns the patient code or 'Legacy' for patients without a code
  String get displayCode => patientCode ?? 'Legacy';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientCode': patientCode,
      'name': name,
      'age': age,
      'gender': gender,
      'diagnosisSummary': diagnosisSummary,
      'wardNumber': wardNumber,
      'bedNumber': bedNumber,
      'admissionDate': Timestamp.fromDate(admissionDate),
      'attendingDoctorId': attendingDoctorId,
      'attendingDoctorName': attendingDoctorName,
      'allergies': allergies,
      'specialNotes': specialNotes,
      'isCritical': isCritical,
      'status': status,
      'assignedNurseId': assignedNurseId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      id: map['id'] ?? '',
      patientCode: map['patientCode'],
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      diagnosisSummary: map['diagnosisSummary'] ?? '',
      wardNumber: map['wardNumber'] ?? 0,
      bedNumber: map['bedNumber'] ?? 0,
      admissionDate:
          (map['admissionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attendingDoctorId: map['attendingDoctorId'] ?? '',
      attendingDoctorName: map['attendingDoctorName'] ?? '',
      allergies: List<String>.from(map['allergies'] ?? []),
      specialNotes: map['specialNotes'],
      isCritical: map['isCritical'] ?? false,
      status: map['status'] ?? 'stable',
      assignedNurseId: map['assignedNurseId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PatientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientModel.fromMap({...data, 'id': doc.id});
  }

  PatientModel copyWith({
    String? id,
    String? patientCode,
    String? name,
    int? age,
    String? gender,
    String? diagnosisSummary,
    int? wardNumber,
    int? bedNumber,
    DateTime? admissionDate,
    String? attendingDoctorId,
    String? attendingDoctorName,
    List<String>? allergies,
    String? specialNotes,
    bool? isCritical,
    String? status,
    String? assignedNurseId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      patientCode: patientCode ?? this.patientCode,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      diagnosisSummary: diagnosisSummary ?? this.diagnosisSummary,
      wardNumber: wardNumber ?? this.wardNumber,
      bedNumber: bedNumber ?? this.bedNumber,
      admissionDate: admissionDate ?? this.admissionDate,
      attendingDoctorId: attendingDoctorId ?? this.attendingDoctorId,
      attendingDoctorName: attendingDoctorName ?? this.attendingDoctorName,
      allergies: allergies ?? this.allergies,
      specialNotes: specialNotes ?? this.specialNotes,
      isCritical: isCritical ?? this.isCritical,
      status: status ?? this.status,
      assignedNurseId: assignedNurseId ?? this.assignedNurseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get wardBedLabel => 'Ward $wardNumber - Bed $bedNumber';

  bool get hasAllergies => allergies.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PatientModel &&
        other.id == id &&
        other.name == name &&
        other.wardNumber == wardNumber &&
        other.bedNumber == bedNumber;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        wardNumber.hashCode ^
        bedNumber.hashCode;
  }
}
