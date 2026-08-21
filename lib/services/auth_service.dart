import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

/// Result of an admin provisioning attempt.
enum CreateStaffResult {
  /// Account + profile created successfully.
  created,

  /// An account with this email already existed (e.g. previously deactivated
  /// staff) and its profile was reactivated instead.
  reactivated,
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Secondary Firebase app used to provision new staff accounts without
  // replacing the admin's own session (createUserWithEmailAndPassword signs
  // its app instance in as the new user, so it must never run on the primary
  // app while an admin is logged in).
  static const String _provisionerAppName = 'staff-provisioner';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password.
  //
  // Pure authentication + profile fetch: the caller decides when/whether to
  // persist the session via [saveUserSession], so an abandoned/timed-out sign-in
  // can never leave a stale session behind.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = result.user;
    if (user == null) {
      throw Exception('Sign-in failed');
    }

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      // Don't stay signed in as an account with no staff profile.
      await _auth.signOut();
      throw Exception(
        'No staff profile found for this account. Ask an administrator to '
        'provision your account.',
      );
    }

    final userModel = UserModel.fromFirestore(userDoc);

    if (!userModel.isActive) {
      await _auth.signOut();
      throw Exception(
        'This account has been deactivated. Contact your administrator.',
      );
    }

    // Update last login time (server clock).
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update({'lastLoginAt': FieldValue.serverTimestamp()});

    return userModel;
  }

  /// Provision a new staff account on behalf of an admin (bug #5 fix).
  ///
  /// The Auth user is created on a secondary Firebase app instance so the
  /// admin's session is untouched. The Firestore profile doc is written from
  /// the admin's primary session (required by firestore.rules: only admins can
  /// create /users docs). If the profile write fails, the freshly created Auth
  /// user is deleted again so no orphaned half-provisioned account remains.
  Future<UserModel> createStaffAccount({
    required String email,
    required String password,
    required String name,
    required String employeeId,
    required String role,
    String? assignedWard,
    String? specialization,
  }) async {
    FirebaseApp? provisionerApp;
    try {
      provisionerApp = await Firebase.initializeApp(
        name: _provisionerAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Already initialized from a previous call.
      provisionerApp = Firebase.app(_provisionerAppName);
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: provisionerApp);
    UserCredential? credential;

    try {
      credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUid = credential.user!.uid;
      final userModel = UserModel(
        id: newUid,
        name: name,
        email: email,
        employeeId: employeeId,
        role: role,
        assignedWard: assignedWard,
        specialization: specialization,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Profile doc is written by the ADMIN's session (primary app), which is
      // what the security rules require.
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(newUid)
          .set(userModel.toMap());

      return userModel;
    } catch (e) {
      // Roll back the orphaned Auth user if the profile write failed.
      final newUser = credential?.user ?? secondaryAuth.currentUser;
      if (newUser != null && !newUser.isAnonymous) {
        try {
          await newUser.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      // Never leave the provisioner signed in.
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
    }
  }

  /// Reactivate a previously deactivated staff member (bug #15 companion).
  ///
  /// The client SDK cannot delete another user's Auth record, so "removing"
  /// staff deactivates them instead; their email stays reserved in Firebase
  /// Auth. Re-adding the same email lands here: find the existing profile by
  /// email and bring it back.
  ///
  /// NEW-6: the password typed into the Add Staff dialog CANNOT be applied to
  /// an existing account from the client, so we trigger a password-reset
  /// email instead - otherwise "reactivated" would still leave the nurse
  /// locked out behind their old (possibly forgotten) password. Returns null
  /// if no deactivatable profile exists.
  Future<UserModel?> reactivateStaffByEmail(String email) async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final existing = UserModel.fromFirestore(doc);
    if (existing.isActive) return null;

    await doc.reference.update({'isActive': true});

    // Best-effort: a failed reset email doesn't undo the reactivation.
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {}

    return existing.copyWith(isActive: true);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await clearUserSession();
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.prefIsLoggedIn) ?? false;
  }

  // Get saved user role
  Future<String?> getSavedUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserRole);
  }

  // Get saved user ID
  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserId);
  }

  // Save user session to shared preferences (call after successful sign-in)
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserId, user.id);
    await prefs.setString(AppConstants.prefUserRole, user.role);
    await prefs.setString(AppConstants.prefUserName, user.name);
    await prefs.setBool(AppConstants.prefIsLoggedIn, true);
  }

  // Clear user session
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefUserRole);
    await prefs.remove(AppConstants.prefUserName);
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  // Get all doctors (for nurse to select).
  // Throws on failure - callers must surface errors instead of silently
  // rendering an empty list (an empty dropdown silently blocks admissions).
  Future<List<UserModel>> getAllDoctors() {
    return _queryActiveStaff(AppConstants.roleDoctor);
  }

  // Get all nurses (for doctor to see). Throws on failure.
  Future<List<UserModel>> getAllNurses() {
    return _queryActiveStaff(AppConstants.roleNurse);
  }

  Future<List<UserModel>> _queryActiveStaff(String role) async {
    final querySnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .get();

    return querySnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
  }
}
