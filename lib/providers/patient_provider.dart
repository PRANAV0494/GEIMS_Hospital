import 'package:flutter/foundation.dart';
import '../core/service_locator.dart';
import '../models/patient_model.dart';
import '../models/vitals_model.dart';
import '../models/medication_model.dart';
import '../services/database_service.dart';

class PatientProvider extends ChangeNotifier {
  final DatabaseService _databaseService = getIt<DatabaseService>();

  PatientModel? _selectedPatient;
  List<PatientModel> _patients = [];
  List<VitalsModel> _vitals = [];
  List<MedicationModel> _medications = [];
  bool _isLoading = false;
  String? _errorMessage;

  PatientModel? get selectedPatient => _selectedPatient;
  List<PatientModel> get patients => _patients;
  List<VitalsModel> get vitals => _vitals;
  List<MedicationModel> get medications => _medications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Select a patient
  void selectPatient(PatientModel patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  // Clear selected patient
  void clearSelectedPatient() {
    _selectedPatient = null;
    _vitals = [];
    _medications = [];
    notifyListeners();
  }

  // Add new patient
  Future<bool> addPatient(PatientModel patient) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _databaseService.addPatient(patient);
      if (id != null) {
        return true;
      }
      _errorMessage = 'Failed to add patient';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update patient
  Future<bool> updatePatient(PatientModel patient) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _databaseService.updatePatient(patient);
      if (success) {
        _selectedPatient = patient;
        return true;
      }
      _errorMessage = 'Failed to update patient';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add vitals record
  Future<bool> addVitals(VitalsModel vitals) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _databaseService.addVitals(vitals);
      if (id != null) {
        return true;
      }
      _errorMessage = 'Failed to add vitals';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add medication
  Future<bool> addMedication(MedicationModel medication) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = await _databaseService.addMedication(medication);
      if (id != null) {
        return true;
      }
      _errorMessage = 'Failed to add medication';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Administer medication
  Future<bool> administerMedication({
    required String medicationId,
    required String nurseId,
    required String nurseName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _databaseService.administerMedication(
        medicationId: medicationId,
        nurseId: nurseId,
        nurseName: nurseName,
      );
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get latest vitals for display
  Future<VitalsModel?> getLatestVitals(String patientId) async {
    return await _databaseService.getLatestVitals(patientId);
  }

  // Get pending medications
  Future<List<MedicationModel>> getPendingMedications(String patientId) async {
    return await _databaseService.getPendingMedications(patientId);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
