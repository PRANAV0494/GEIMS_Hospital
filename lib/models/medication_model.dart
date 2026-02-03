import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationModel {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String route; // 'oral', 'iv', 'im', 'sc', 'topical'
  final String frequency; // 'once', 'bid', 'tid', 'qid', 'prn'
  final DateTime scheduledTime;
  final DateTime? administeredTime;
  final String? administeredById;
  final String? administeredByName;
  final bool isInjection;
  final bool isAdministered;
  final String? notes;
  final String prescribedById;
  final String prescribedByName;
  final DateTime createdAt;

  MedicationModel({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.route,
    required this.frequency,
    required this.scheduledTime,
    this.administeredTime,
    this.administeredById,
    this.administeredByName,
    this.isInjection = false,
    this.isAdministered = false,
    this.notes,
    required this.prescribedById,
    required this.prescribedByName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'name': name,
      'dosage': dosage,
      'route': route,
      'frequency': frequency,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'administeredTime': administeredTime != null 
          ? Timestamp.fromDate(administeredTime!) 
          : null,
      'administeredById': administeredById,
      'administeredByName': administeredByName,
      'isInjection': isInjection,
      'isAdministered': isAdministered,
      'notes': notes,
      'prescribedById': prescribedById,
      'prescribedByName': prescribedByName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MedicationModel.fromMap(Map<String, dynamic> map) {
    return MedicationModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      route: map['route'] ?? 'oral',
      frequency: map['frequency'] ?? 'once',
      scheduledTime: (map['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      administeredTime: (map['administeredTime'] as Timestamp?)?.toDate(),
      administeredById: map['administeredById'],
      administeredByName: map['administeredByName'],
      isInjection: map['isInjection'] ?? false,
      isAdministered: map['isAdministered'] ?? false,
      notes: map['notes'],
      prescribedById: map['prescribedById'] ?? '',
      prescribedByName: map['prescribedByName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MedicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicationModel.fromMap({...data, 'id': doc.id});
  }

  MedicationModel copyWith({
    String? id,
    String? patientId,
    String? name,
    String? dosage,
    String? route,
    String? frequency,
    DateTime? scheduledTime,
    DateTime? administeredTime,
    String? administeredById,
    String? administeredByName,
    bool? isInjection,
    bool? isAdministered,
    String? notes,
    String? prescribedById,
    String? prescribedByName,
    DateTime? createdAt,
  }) {
    return MedicationModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      route: route ?? this.route,
      frequency: frequency ?? this.frequency,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      administeredTime: administeredTime ?? this.administeredTime,
      administeredById: administeredById ?? this.administeredById,
      administeredByName: administeredByName ?? this.administeredByName,
      isInjection: isInjection ?? this.isInjection,
      isAdministered: isAdministered ?? this.isAdministered,
      notes: notes ?? this.notes,
      prescribedById: prescribedById ?? this.prescribedById,
      prescribedByName: prescribedByName ?? this.prescribedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => !isAdministered && scheduledTime.isBefore(DateTime.now());
  bool get isOverdue => !isAdministered && scheduledTime.isBefore(DateTime.now().subtract(const Duration(minutes: 30)));

  String get routeLabel {
    switch (route) {
      case 'oral': return 'Oral';
      case 'iv': return 'IV';
      case 'im': return 'IM';
      case 'sc': return 'SC';
      case 'topical': return 'Topical';
      default: return route.toUpperCase();
    }
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'once': return 'Once';
      case 'bid': return 'Twice Daily';
      case 'tid': return 'Three Times Daily';
      case 'qid': return 'Four Times Daily';
      case 'prn': return 'As Needed';
      default: return frequency.toUpperCase();
    }
  }
}
