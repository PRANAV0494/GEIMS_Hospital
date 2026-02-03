import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import '../models/vitals_model.dart';
import '../models/medication_model.dart';
import '../models/message_model.dart';
import '../models/task_model.dart';
import '../config/constants.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== USERS ====================

  // Update user profile
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete user (for admin)
  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== HOSPITAL CONFIG ====================

  // Get hospital configuration (wards, beds)
  Future<Map<String, dynamic>?> getHospitalConfig() async {
    try {
      final doc = await _firestore.collection('config').doc('hospital').get();
      if (doc.exists) {
        return doc.data();
      }
      // Return default config if doesn't exist
      return {'totalWards': 5, 'bedsPerWard': 10};
    } catch (e) {
      return null;
    }
  }

  // Update hospital configuration
  Future<bool> updateHospitalConfig({
    required int totalWards,
    required int bedsPerWard,
  }) async {
    try {
      await _firestore.collection('config').doc('hospital').set({
        'totalWards': totalWards,
        'bedsPerWard': bedsPerWard,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PATIENTS ====================

  // Get all patients (for global search)
  Stream<List<PatientModel>> getAllPatients() {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .limit(100) // Limit to prevent loading excessive data
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get all patients for a specific ward
  Stream<List<PatientModel>> getPatientsForWard(int wardNumber) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('wardNumber', isEqualTo: wardNumber)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get all patients for a doctor
  Stream<List<PatientModel>> getPatientsForDoctor(String doctorId) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('attendingDoctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
          final patients = snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
          // Sort client-side to avoid needing composite index
          patients.sort((a, b) {
            final wardCompare = a.wardNumber.compareTo(b.wardNumber);
            if (wardCompare != 0) return wardCompare;
            return a.bedNumber.compareTo(b.bedNumber);
          });
          return patients;
        });
  }

  // Get patients by ward for nurse
  Stream<List<PatientModel>> getPatientsByWard(int wardNumber) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('wardNumber', isEqualTo: wardNumber)
        .snapshots()
        .map((snapshot) {
          final patients = snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
          // Sort client-side
          patients.sort((a, b) => a.bedNumber.compareTo(b.bedNumber));
          return patients;
        });
  }

  // Get single patient
  Future<PatientModel?> getPatient(String patientId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.patientsCollection)
          .doc(patientId)
          .get();
      if (doc.exists) {
        return PatientModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get next patient code with atomic increment
  Future<String> _getNextPatientCode() async {
    final counterRef = _firestore.collection('config').doc('patient_counter');

    return await _firestore.runTransaction<String>((transaction) async {
      final counterDoc = await transaction.get(counterRef);

      int nextNumber;
      if (counterDoc.exists) {
        nextNumber = (counterDoc.data()?['counter'] ?? 0) + 1;
      } else {
        nextNumber = 1;
      }

      transaction.set(counterRef, {
        'counter': nextNumber,
      }, SetOptions(merge: true));

      // Format as GEIMS0001, GEIMS0002, etc.
      return 'GEIMS${nextNumber.toString().padLeft(4, '0')}';
    });
  }

  // Add new patient
  Future<String?> addPatient(PatientModel patient) async {
    try {
      final id = _uuid.v4();
      final patientCode = await _getNextPatientCode();
      final newPatient = patient.copyWith(id: id, patientCode: patientCode);
      await _firestore
          .collection(AppConstants.patientsCollection)
          .doc(id)
          .set(newPatient.toMap());
      return id;
    } catch (e) {
      return null;
    }
  }

  // Update patient
  Future<bool> updatePatient(PatientModel patient) async {
    try {
      await _firestore
          .collection(AppConstants.patientsCollection)
          .doc(patient.id)
          .update(patient.copyWith(updatedAt: DateTime.now()).toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== VITALS ====================

  // Get vitals for patient (real-time stream)
  Stream<List<VitalsModel>> getVitalsForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.vitalsCollection)
        .where('patientId', isEqualTo: patientId)
        .limit(50) // Server-side limit instead of client-side
        .snapshots()
        .map((snapshot) {
          final vitals = snapshot.docs
              .map((doc) => VitalsModel.fromFirestore(doc))
              .toList();
          // Sort client-side by timestamp descending
          vitals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return vitals;
        });
  }

  // Get latest vitals for patient
  Future<VitalsModel?> getLatestVitals(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.vitalsCollection)
          .where('patientId', isEqualTo: patientId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final vitals = snapshot.docs
            .map((doc) => VitalsModel.fromFirestore(doc))
            .toList();
        // Sort client-side and get the latest
        vitals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return vitals.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Add vitals record
  Future<String?> addVitals(VitalsModel vitals) async {
    try {
      final id = _uuid.v4();
      final newVitals = VitalsModel(
        id: id,
        patientId: vitals.patientId,
        recordedById: vitals.recordedById,
        recordedByName: vitals.recordedByName,
        timestamp: vitals.timestamp,
        heartRate: vitals.heartRate,
        systolicBP: vitals.systolicBP,
        diastolicBP: vitals.diastolicBP,
        oxygenSaturation: vitals.oxygenSaturation,
        temperature: vitals.temperature,
        respiratoryRate: vitals.respiratoryRate,
        glucoseLevel: vitals.glucoseLevel,
        notes: vitals.notes,
        alerts: vitals.calculateAlerts(),
      );
      await _firestore
          .collection(AppConstants.vitalsCollection)
          .doc(id)
          .set(newVitals.toMap());

      // Check for alerts and update patient status
      if (newVitals.hasAnyAlert) {
        await _firestore
            .collection(AppConstants.patientsCollection)
            .doc(vitals.patientId)
            .update({'status': AppConstants.statusPending});
      }

      return id;
    } catch (e) {
      return null;
    }
  }

  // ==================== MEDICATIONS ====================

  // Get medications for patient
  Stream<List<MedicationModel>> getMedicationsForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.medicationsCollection)
        .where('patientId', isEqualTo: patientId)
        .limit(50) // Server-side limit
        .snapshots()
        .map((snapshot) {
          final meds = snapshot.docs
              .map((doc) => MedicationModel.fromFirestore(doc))
              .toList();
          // Sort client-side by scheduledTime descending
          meds.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
          return meds;
        });
  }

  // Get pending medications for patient
  Future<List<MedicationModel>> getPendingMedications(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.medicationsCollection)
          .where('patientId', isEqualTo: patientId)
          .get();

      final meds = snapshot.docs
          .map((doc) => MedicationModel.fromFirestore(doc))
          .where((med) => !med.isAdministered)
          .toList();
      // Sort client-side
      meds.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return meds;
    } catch (e) {
      return [];
    }
  }

  // Add medication
  Future<String?> addMedication(MedicationModel medication) async {
    try {
      final id = _uuid.v4();
      final newMedication = medication.copyWith(id: id);
      await _firestore
          .collection(AppConstants.medicationsCollection)
          .doc(id)
          .set(newMedication.toMap());
      return id;
    } catch (e) {
      return null;
    }
  }

  // Administer medication
  Future<bool> administerMedication({
    required String medicationId,
    required String nurseId,
    required String nurseName,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.medicationsCollection)
          .doc(medicationId)
          .update({
            'isAdministered': true,
            'administeredTime': Timestamp.now(),
            'administeredById': nurseId,
            'administeredByName': nurseName,
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== MESSAGES ====================

  // Get messages for a patient conversation (between nurse and doctor)
  Stream<List<MessageModel>> getMessagesForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          // Sort client-side by sentAt ascending
          messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
          return messages;
        });
  }

  // Get unread messages for user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.messagesCollection)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Send message
  Future<String?> sendMessage(MessageModel message) async {
    try {
      final id = _uuid.v4();
      final newMessage = message.copyWith(id: id, isDelivered: true);
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(id)
          .set(newMessage.toMap());
      return id;
    } catch (e) {
      return null;
    }
  }

  // Mark message as read
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'isRead': true, 'readAt': Timestamp.now()});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== AUDIT LOGS ====================

  // Add audit log entry
  Future<void> addAuditLog({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final id = _uuid.v4();
      await _firestore
          .collection(AppConstants.auditLogsCollection)
          .doc(id)
          .set({
            'id': id,
            'userId': userId,
            'action': action,
            'entityType': entityType,
            'entityId': entityId,
            'timestamp': Timestamp.now(),
            'metadata': metadata,
          });
    } catch (e) {
      // Silently fail for audit logs
    }
  }
  // ==================== TASKS ====================

  // Get tasks for ward
  Stream<List<TaskModel>> getTasksForWard(int wardNumber) {
    return _firestore
        .collection('tasks')
        .where('wardNumber', isEqualTo: wardNumber)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList();
          // Sort: Incomplete first, then by date
          tasks.sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return a.dueDate.compareTo(b.dueDate);
          });
          return tasks;
        });
  }

  // Add task
  Future<String?> addTask(TaskModel task) async {
    try {
      final id = _uuid.v4();
      final newTask = task.copyWith(id: id);
      await _firestore.collection('tasks').doc(id).set(newTask.toMap());
      return id;
    } catch (e) {
      return null;
    }
  }

  // Update task status with completion details
  Future<bool> updateTaskStatus({
    required String taskId,
    required bool isCompleted,
    String? completedByNurseId,
    String? completedByNurseName,
  }) async {
    try {
      final updates = <String, dynamic>{'isCompleted': isCompleted};

      if (isCompleted) {
        updates['completedByNurseId'] = completedByNurseId;
        updates['completedByNurseName'] = completedByNurseName;
        updates['completedAt'] = Timestamp.now();
      } else {
        updates['completedByNurseId'] = null;
        updates['completedByNurseName'] = null;
        updates['completedAt'] = null;
      }

      await _firestore.collection('tasks').doc(taskId).update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete task
  Future<bool> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
