import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import '../models/vitals_model.dart';
import '../models/medication_model.dart';
import '../models/message_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

/// Outcome of a medication administration attempt.
enum MedicationAdminResult {
  /// This call administered the dose.
  success,

  /// The dose was already administered (e.g. by another device moments
  /// earlier) - nothing was changed. Prevents double-dosing.
  alreadyAdministered,

  /// The write failed.
  failed,
}

/// Outcome of a task completion attempt.
enum TaskUpdateResult { success, alreadyCompleted, failed }

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== RETRY LOGIC ====================

  /// Retry helper with exponential backoff for transient failures
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts) {
          rethrow;
        }
        // Check if it's a retryable error (network, timeout)
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('unavailable')) {
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        } else {
          rethrow; // Non-retryable error
        }
      }
    }
  }

  // ==================== USERS ====================

  // Update user profile
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _withRetry(
        () => _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update(data),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate a staff member (bug #15).
  ///
  /// The client Auth SDK cannot delete another user's login, so deletion is
  /// soft: the profile doc is flagged inactive, which removes them from all
  /// staff rosters and blocks their next sign-in (see AuthService). Their
  /// email stays reserved in Firebase Auth - re-adding it reactivates the
  /// account instead (see AuthService.reactivateStaffByEmail).
  Future<bool> deactivateUser(String userId) async {
    try {
      await _withRetry(
        () => _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({
              'isActive': false,
              'deactivatedAt': FieldValue.serverTimestamp(),
            }),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Live staff roster by role (admin dashboards stay current without
  // manual refresh).
  Stream<List<UserModel>> streamActiveStaff(String role) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
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

  // Get all patients (for global search - limited for performance)
  Stream<List<PatientModel>> getAllPatients() {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .orderBy('wardNumber')
        .orderBy('bedNumber')
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get unique wards for a doctor (efficient aggregation)
  Future<List<int>> getDoctorWards(String doctorId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.patientsCollection)
          .where('attendingDoctorId', isEqualTo: doctorId)
          .get();

      final wards =
          snapshot.docs
              .map((doc) => doc.data()['wardNumber'] as int)
              .toSet()
              .toList()
            ..sort();
      return wards;
    } catch (e) {
      return [];
    }
  }

  // Get all patients for a specific ward
  Stream<List<PatientModel>> getPatientsForWard(int wardNumber) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('wardNumber', isEqualTo: wardNumber)
        .orderBy('bedNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get all patients for a doctor with server-side ordering
  Stream<List<PatientModel>> getPatientsForDoctor(String doctorId) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('attendingDoctorId', isEqualTo: doctorId)
        .orderBy('wardNumber')
        .orderBy('bedNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get patients by ward for nurse with server-side ordering
  Stream<List<PatientModel>> getPatientsByWard(int wardNumber) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('wardNumber', isEqualTo: wardNumber)
        .orderBy('bedNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PatientModel.fromFirestore(doc))
              .toList();
        });
  }

  // Live stream of the (at most one) patient occupying a ward/bed.
  // Used by the nurse hub tabs so an admission into an empty bed appears
  // immediately instead of requiring a ward re-pick (bug #18), and so a fast
  // ward switch can't file data under a stale patient (bug #17).
  Stream<PatientModel?> getPatientForBed(int wardNumber, int bedNumber) {
    return _firestore
        .collection(AppConstants.patientsCollection)
        .where('wardNumber', isEqualTo: wardNumber)
        .where('bedNumber', isEqualTo: bedNumber)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return PatientModel.fromFirestore(snapshot.docs.first);
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
      await _withRetry(
        () => _firestore
            .collection(AppConstants.patientsCollection)
            .doc(id)
            .set(newPatient.toMap()),
      );
      return id;
    } catch (e) {
      return null;
    }
  }

  // Update patient (bug #6).
  //
  // Writes ONLY the fields the edit form owns. The old code wrote the full
  // model map, and because the form doesn't carry patientCode /
  // assignedNurseId, those were overwritten with null on every edit - wiping
  // the patient's GEIMS ID, nurse assignment and pending status.
  // patientCode/id/createdAt/assignedNurseId are preserved server-side
  // (and patientCode/id/createdAt are additionally locked by firestore.rules).
  Future<bool> updatePatient(PatientModel patient) async {
    try {
      final updates = <String, dynamic>{
        'name': patient.name,
        'age': patient.age,
        'gender': patient.gender,
        'diagnosisSummary': patient.diagnosisSummary,
        'wardNumber': patient.wardNumber,
        'bedNumber': patient.bedNumber,
        'admissionDate': Timestamp.fromDate(patient.admissionDate),
        'attendingDoctorId': patient.attendingDoctorId,
        'attendingDoctorName': patient.attendingDoctorName,
        'allergies': patient.allergies,
        'specialNotes': patient.specialNotes,
        'isCritical': patient.isCritical,
        'status': patient.status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _withRetry(
        () => _firestore
            .collection(AppConstants.patientsCollection)
            .doc(patient.id)
            .update(updates),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== VITALS ====================

  // Get vitals for patient with server-side ordering and pagination
  Stream<List<VitalsModel>> getVitalsForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.vitalsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VitalsModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get latest vitals for patient (optimized with limit 1)
  Future<VitalsModel?> getLatestVitals(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.vitalsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return VitalsModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Add vitals record (bugs #25 / #40 / NEW-4).
  //
  // The vitals doc and the patient status update are committed as ONE atomic
  // batch. A batch (unlike a transaction) is queued by Firestore's offline
  // persistence, so nurses can record vitals without connectivity - a plain
  // transaction here silently dropped that capability.
  //
  // [currentPatientStatus] comes from the caller's live patient stream and
  // preserves the #40 fix: abnormal-but-not-critical readings set status to
  // 'pending', but a CRITICAL patient is never downgraded out of the
  // critical count.
  Future<String?> addVitals(
    VitalsModel vitals, {
    String? currentPatientStatus,
  }) async {
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

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(AppConstants.vitalsCollection).doc(id),
        newVitals.toMap(),
      );

      if (newVitals.hasAnyAlert &&
          currentPatientStatus != null &&
          currentPatientStatus != AppConstants.statusCritical) {
        batch.update(
          _firestore
              .collection(AppConstants.patientsCollection)
              .doc(vitals.patientId),
          {'status': AppConstants.statusPending},
        );
      }

      await batch.commit();
      return id;
    } catch (e) {
      return null;
    }
  }

  // ==================== MEDICATIONS ====================

  // Get medications for patient with server-side ordering
  Stream<List<MedicationModel>> getMedicationsForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.medicationsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('scheduledTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MedicationModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get pending medications for patient
  Future<List<MedicationModel>> getPendingMedications(String patientId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.medicationsCollection)
          .where('patientId', isEqualTo: patientId)
          .where('isAdministered', isEqualTo: false)
          .orderBy('scheduledTime')
          .get();

      return snapshot.docs
          .map((doc) => MedicationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Add medication with retry
  Future<String?> addMedication(MedicationModel medication) async {
    try {
      final id = _uuid.v4();
      final newMedication = medication.copyWith(id: id);
      await _withRetry(
        () => _firestore
            .collection(AppConstants.medicationsCollection)
            .doc(id)
            .set(newMedication.toMap()),
      );
      return id;
    } catch (e) {
      return null;
    }
  }

  /// Administer medication (bug #12).
  ///
  /// Runs as a transaction with an "already administered?" precondition, so
  /// two nurses tapping "Give" on different devices in the same sync window
  /// can never double-dose a patient: the second write observes the first and
  /// reports [MedicationAdminResult.alreadyAdministered] instead of blindly
  /// overwriting the record.
  Future<MedicationAdminResult> administerMedication({
    required String medicationId,
    required String nurseId,
    required String nurseName,
  }) async {
    try {
      final result = await _firestore.runTransaction<MedicationAdminResult>((
        transaction,
      ) async {
        final ref = _firestore
            .collection(AppConstants.medicationsCollection)
            .doc(medicationId);
        final snapshot = await transaction.get(ref);

        if (!snapshot.exists) {
          return MedicationAdminResult.failed;
        }
        if (snapshot.data()?['isAdministered'] == true) {
          return MedicationAdminResult.alreadyAdministered;
        }

        transaction.update(ref, {
          'isAdministered': true,
          'administeredTime': FieldValue.serverTimestamp(),
          'administeredById': nurseId,
          'administeredByName': nurseName,
        });
        return MedicationAdminResult.success;
      });
      return result;
    } catch (e) {
      return MedicationAdminResult.failed;
    }
  }

  // ==================== MESSAGES ====================

  // Get messages for a patient conversation (bug #3).
  //
  // Fetch the LATEST 50 (descending) and reverse for display. The old query
  // ordered ascending with limit(50), which permanently pinned the window to
  // the OLDEST 50 messages - message #51 ("start IV antibiotics now") was
  // never rendered for either party once a conversation passed 50.
  Stream<List<MessageModel>> getMessagesForPatient(String patientId) {
    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          return messages.reversed.toList();
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

  // Send message with retry
  Future<String?> sendMessage(MessageModel message) async {
    try {
      final id = _uuid.v4();
      final newMessage = message.copyWith(id: id, isDelivered: true);
      await _withRetry(
        () => _firestore
            .collection(AppConstants.messagesCollection)
            .doc(id)
            .set(newMessage.toMap()),
      );
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
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== AUDIT LOGS ====================

  // Add audit log entry (fire and forget, non-blocking)
  Future<void> addAuditLog({
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) async {
    // Use unawaited to prevent blocking the main operation
    // Errors are logged but don't affect the calling code
    final logId = _uuid.v4();
    _firestore
        .collection(AppConstants.auditLogsCollection)
        .doc(logId)
        .set({
          // The embedded id IS the doc id (previously two different UUIDs,
          // making logs impossible to correlate - bug #33).
          'id': logId,
          'userId': userId,
          'action': action,
          'entityType': entityType,
          'entityId': entityId,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata,
        })
        .catchError((e) {
          // Log silently - audit failures shouldn't break the app
          return null;
        });
  }

  // ==================== TASKS ====================

  // Get tasks for ward with server-side ordering
  Stream<List<TaskModel>> getTasksForWard(int wardNumber) {
    return _firestore
        .collection('tasks')
        .where('wardNumber', isEqualTo: wardNumber)
        .orderBy('isCompleted')
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList();
        });
  }

  // Add task with retry
  Future<String?> addTask(TaskModel task) async {
    try {
      final id = _uuid.v4();
      final newTask = task.copyWith(id: id);
      await _withRetry(
        () => _firestore.collection('tasks').doc(id).set(newTask.toMap()),
      );
      return id;
    } catch (e) {
      return null;
    }
  }

  /// Update task completion state (bug #12).
  ///
  /// Transactional with an isCompleted precondition, so two devices tapping
  /// the checkbox simultaneously can't both claim completion.
  Future<TaskUpdateResult> updateTaskStatus({
    required String taskId,
    required bool isCompleted,
    String? completedByNurseId,
    String? completedByNurseName,
  }) async {
    try {
      final result = await _firestore.runTransaction<TaskUpdateResult>((
        transaction,
      ) async {
        final ref = _firestore.collection('tasks').doc(taskId);
        final snapshot = await transaction.get(ref);

        if (!snapshot.exists) {
          return TaskUpdateResult.failed;
        }
        if (snapshot.data()?['isCompleted'] == isCompleted) {
          return isCompleted
              ? TaskUpdateResult.alreadyCompleted
              : TaskUpdateResult.success;
        }

        final updates = <String, dynamic>{'isCompleted': isCompleted};
        if (isCompleted) {
          updates['completedByNurseId'] = completedByNurseId;
          updates['completedByNurseName'] = completedByNurseName;
          updates['completedAt'] = FieldValue.serverTimestamp();
        } else {
          updates['completedByNurseId'] = null;
          updates['completedByNurseName'] = null;
          updates['completedAt'] = null;
        }

        transaction.update(ref, updates);
        return TaskUpdateResult.success;
      });
      return result;
    } catch (e) {
      return TaskUpdateResult.failed;
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
