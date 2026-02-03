import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';

class VitalsModel {
  final String id;
  final String patientId;
  final String recordedById;
  final String recordedByName;
  final DateTime timestamp;
  final int heartRate;
  final int systolicBP;
  final int diastolicBP;
  final double oxygenSaturation;
  final double temperature;
  final int respiratoryRate;
  final double glucoseLevel;
  final String? notes;
  final Map<String, bool> alerts;

  VitalsModel({
    required this.id,
    required this.patientId,
    required this.recordedById,
    required this.recordedByName,
    required this.timestamp,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.oxygenSaturation,
    required this.temperature,
    required this.respiratoryRate,
    required this.glucoseLevel,
    this.notes,
    Map<String, bool>? alerts,
  }) : alerts = alerts ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'recordedById': recordedById,
      'recordedByName': recordedByName,
      'timestamp': Timestamp.fromDate(timestamp),
      'heartRate': heartRate,
      'systolicBP': systolicBP,
      'diastolicBP': diastolicBP,
      'oxygenSaturation': oxygenSaturation,
      'temperature': temperature,
      'respiratoryRate': respiratoryRate,
      'glucoseLevel': glucoseLevel,
      'notes': notes,
      'alerts': alerts,
    };
  }

  factory VitalsModel.fromMap(Map<String, dynamic> map) {
    return VitalsModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      recordedById: map['recordedById'] ?? '',
      recordedByName: map['recordedByName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      heartRate: map['heartRate'] ?? 0,
      systolicBP: map['systolicBP'] ?? 0,
      diastolicBP: map['diastolicBP'] ?? 0,
      oxygenSaturation: (map['oxygenSaturation'] ?? 0).toDouble(),
      temperature: (map['temperature'] ?? 0).toDouble(),
      respiratoryRate: map['respiratoryRate'] ?? 0,
      glucoseLevel: (map['glucoseLevel'] ?? 0).toDouble(),
      notes: map['notes'],
      alerts: Map<String, bool>.from(map['alerts'] ?? {}),
    );
  }

  factory VitalsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VitalsModel.fromMap({...data, 'id': doc.id});
  }

  String get bloodPressure => '$systolicBP/$diastolicBP';

  bool get hasAnyAlert => alerts.values.any((alert) => alert);

  // Instance getters for abnormal vital detection
  bool get isHeartRateAbnormal => !isHeartRateNormal(heartRate);
  bool get isOxygenLow => !isOxygenNormal(oxygenSaturation);
  bool get isTemperatureAbnormal => !isTemperatureNormal(temperature);
  bool get isRespiratoryAbnormal => !isRespiratoryRateNormal(respiratoryRate);
  bool get isGlucoseAbnormal => !isGlucoseNormal(glucoseLevel);
  bool get isBPAbnormal => !isSystolicBPNormal(systolicBP) || !isDiastolicBPNormal(diastolicBP);

  // Check if vital is within normal range
  static bool isHeartRateNormal(int value) {
    final range = AppConstants.vitalsNormalRanges['heartRate']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isOxygenNormal(double value) {
    final range = AppConstants.vitalsNormalRanges['oxygenSaturation']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isTemperatureNormal(double value) {
    final range = AppConstants.vitalsNormalRanges['temperature']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isRespiratoryRateNormal(int value) {
    final range = AppConstants.vitalsNormalRanges['respiratoryRate']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isGlucoseNormal(double value) {
    final range = AppConstants.vitalsNormalRanges['glucoseLevel']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isSystolicBPNormal(int value) {
    final range = AppConstants.vitalsNormalRanges['systolicBP']!;
    return value >= range['min']! && value <= range['max']!;
  }

  static bool isDiastolicBPNormal(int value) {
    final range = AppConstants.vitalsNormalRanges['diastolicBP']!;
    return value >= range['min']! && value <= range['max']!;
  }

  Map<String, bool> calculateAlerts() {
    return {
      'heartRate': !isHeartRateNormal(heartRate),
      'oxygenSaturation': !isOxygenNormal(oxygenSaturation),
      'temperature': !isTemperatureNormal(temperature),
      'respiratoryRate': !isRespiratoryRateNormal(respiratoryRate),
      'glucoseLevel': !isGlucoseNormal(glucoseLevel),
      'systolicBP': !isSystolicBPNormal(systolicBP),
      'diastolicBP': !isDiastolicBPNormal(diastolicBP),
    };
  }
}
