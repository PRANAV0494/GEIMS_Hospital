import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../core/service_locator.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = getIt<AuthService>();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initializationFailed = false;

  // Guard against stale async completions (bug #16): each sign-in attempt
  // bumps this counter; a late-resolving attempt from a previous call that
  // already timed out must not touch state or persist a session.
  int _signInEpoch = 0;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get initializationFailed => _initializationFailed;
  bool get isLoggedIn => _currentUser != null;
  bool get isNurse => _currentUser?.role == AppConstants.roleNurse;
  bool get isDoctor => _currentUser?.role == AppConstants.roleDoctor;
  bool get isAdmin => _currentUser?.role == 'admin';

  // Initialize - check if user is already logged in.
  // A saved prefs session only counts when Firebase Auth actually still has
  // that user signed in; otherwise we clear the stale flag and show login.
  // A saved session whose profile FAILS to load (e.g. slow network) is
  // surfaced as initializationFailed so the splash can offer a retry instead
  // of dumping a validly logged-in user at the login screen (bug #26).
  Future<void> initialize() async {
    // Don't notify at start - this can cause issues during build
    _isLoading = true;
    _initializationFailed = false;

    try {
      final hasSavedSession = await _authService.isLoggedIn();
      final firebaseUser = _authService.currentUser;

      if (!hasSavedSession || firebaseUser == null) {
        // Either never logged in, or the saved session doesn't match Firebase's
        // actual auth state - treat as logged out rather than trusting prefs.
        await _authService.clearUserSession();
        return;
      }

      final userId = firebaseUser.uid;
      _currentUser = await _authService.getUserData(userId);

      if (_currentUser == null) {
        // Profile load failed (network) or was deleted - let the splash ask
        // the user rather than silently logging them out.
        _initializationFailed = true;
        return;
      }

      if (!_currentUser!.isActive) {
        // Deactivated since last login.
        await _authService.signOut();
        _currentUser = null;
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize: ${e.toString()}';
      _initializationFailed = true;
    } finally {
      _isLoading = false;
      // Use addPostFrameCallback to safely notify after build is complete
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Sign in
  Future<bool> signIn({required String email, required String password}) async {
    final epoch = ++_signInEpoch;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService
          .signIn(email: email, password: password)
          .timeout(const Duration(seconds: 15));

      if (epoch != _signInEpoch) {
        // A newer sign-in attempt superseded this one (e.g. this call timed
        // out in the UI and the user retried). Discard the late result -
        // critically, it must not write a session for the wrong account.
        return false;
      }

      // Session is persisted only here, on a verified, non-stale success.
      await _authService.saveUserSession(user);
      _currentUser = user;
      return true;
    } catch (e) {
      if (epoch == _signInEpoch) {
        _errorMessage = _parseFirebaseError(e.toString());
      }
      return false;
    } finally {
      if (epoch == _signInEpoch) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Provision a new staff account (admin dashboard). Never changes the
  // current admin session - see AuthService.createStaffAccount.
  Future<UserModel?> createStaffAccount({
    required String email,
    required String password,
    required String name,
    required String employeeId,
    required String role,
    String? assignedWard,
    String? specialization,
  }) async {
    try {
      return await _authService.createStaffAccount(
        email: email,
        password: password,
        name: name,
        employeeId: employeeId,
        role: role,
        assignedWard: assignedWard,
        specialization: specialization,
      );
    } catch (e) {
      _errorMessage = _parseFirebaseError(e.toString());
      return null;
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
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    } else if (error.contains('email-already-in-use')) {
      return 'This email is already registered.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please wait before trying again.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('permission-denied')) {
      return 'You don\'t have permission to do that.';
    } else if (error.contains('deactivated') ||
        error.contains('No staff profile')) {
      // Surface our own domain errors verbatim-ish instead of masking them.
      final idx = error.indexOf('Exception: ');
      return idx >= 0 ? error.substring(idx + 'Exception: '.length) : error;
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  // Get all doctors
  Future<List<UserModel>> getAllDoctors() {
    return _authService.getAllDoctors();
  }

  // Get all nurses
  Future<List<UserModel>> getAllNurses() {
    return _authService.getAllNurses();
  }
}
