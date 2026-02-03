import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Fetch user data from Firestore
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(result.user!.uid)
            .get();

        if (userDoc.exists) {
          final userModel = UserModel.fromFirestore(userDoc);
          
          // Update last login time
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(result.user!.uid)
              .update({'lastLoginAt': Timestamp.now()});

          // Save to shared preferences
          await _saveUserSession(userModel);

          return userModel;
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String employeeId,
    required String role,
    String? assignedWard,
    String? specialization,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final userModel = UserModel(
          id: result.user!.uid,
          name: name,
          email: email,
          employeeId: employeeId,
          role: role,
          assignedWard: assignedWard,
          specialization: specialization,
          isActive: true,
          createdAt: DateTime.now(),
        );

        // Save to Firestore
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(result.user!.uid)
            .set(userModel.toMap());

        // Save to shared preferences
        await _saveUserSession(userModel);

        return userModel;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearUserSession();
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

  // Save user session to shared preferences
  Future<void> _saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserId, user.id);
    await prefs.setString(AppConstants.prefUserRole, user.role);
    await prefs.setString(AppConstants.prefUserName, user.name);
    await prefs.setBool(AppConstants.prefIsLoggedIn, true);
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefUserRole);
    await prefs.remove(AppConstants.prefUserName);
    await prefs.setBool(AppConstants.prefIsLoggedIn, false);
  }

  // Get all doctors (for nurse to select)
  Future<List<UserModel>> getAllDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleDoctor)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get all nurses (for doctor to see)
  Future<List<UserModel>> getAllNurses() async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.roleNurse)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
