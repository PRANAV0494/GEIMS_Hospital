import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isNurse => _currentUser?.role == AppConstants.roleNurse;
  bool get isDoctor => _currentUser?.role == AppConstants.roleDoctor;
  bool get isAdmin => _currentUser?.role == 'admin';

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    // Don't notify at start - this can cause issues during build
    _isLoading = true;

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final userId = await _authService.getSavedUserId();
        if (userId != null) {
          _currentUser = await _authService.getUserData(userId);
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize: ${e.toString()}';
    } finally {
      _isLoading = false;
      // Use addPostFrameCallback to safely notify after build is complete
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Add timeout to prevent infinite hanging
      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Login timed out. Please check your connection.');
        },
      );

      if (_currentUser == null) {
        _errorMessage = 'User not found. Please check your credentials.';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = _parseFirebaseError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String employeeId,
    required String role,
    String? assignedWard,
    String? specialization,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        employeeId: employeeId,
        role: role,
        assignedWard: assignedWard,
        specialization: specialization,
      );

      if (_currentUser == null) {
        _errorMessage = 'Failed to create account. Please try again.';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = _parseFirebaseError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _errorMessage = 'Failed to sign out: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh user data (useful after profile updates)
  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    
    try {
      final updatedUser = await _authService.getUserData(_currentUser!.id);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to refresh user: $e');
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Parse Firebase error messages to user-friendly text
  String _parseFirebaseError(String error) {
    if (error.contains('user-not-found')) {
      return 'No user found with this email.';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (error.contains('email-already-in-use')) {
      return 'This email is already registered.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  // Get all doctors
  Future<List<UserModel>> getAllDoctors() async {
    return await _authService.getAllDoctors();
  }

  // Get all nurses  
  Future<List<UserModel>> getAllNurses() async {
    return await _authService.getAllNurses();
  }
}
