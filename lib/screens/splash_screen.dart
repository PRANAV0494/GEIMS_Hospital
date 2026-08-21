import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/logo_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Bug #26: a validly logged-in user on a slow network used to be dumped at
  // the Login screen by a hard 2s timeout. When a saved session fails to
  // initialize we now show a retry prompt instead of navigating anywhere.
  bool _needsRetry = false;

  @override
  void initState() {
    super.initState();

    // Simple fade animation using built-in Flutter animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Start animation immediately
    _controller.forward();

    // Use Future.microtask to ensure this runs after the build phase
    Future.microtask(() => _initializeApp());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    setState(() => _needsRetry = false);

    // Run auth initialization in parallel with splash display
    final authFuture = _initializeAuth();

    // Minimum splash display time - short for snappy feel
    await Future.delayed(const Duration(milliseconds: 600));

    // Wait for auth to complete (with its own timeout)
    await authFuture;

    if (!mounted) return;
    _navigateAfterInit();
  }

  void _navigateAfterInit() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Navigate based on auth state
    if (authProvider.isLoggedIn) {
      if (authProvider.isNurse) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.nurseDashboard);
      } else if (authProvider.isDoctor) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.doctorDashboard);
      } else if (authProvider.isAdmin) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } else if (authProvider.initializationFailed) {
      setState(() => _needsRetry = true);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  Future<void> _initializeAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Auth initialization error/timeout: $e');
      // initialize() may still be running; its own result will land in
      // initializationFailed / isLoggedIn. Mark failure so slow networks get
      // the retry prompt rather than an automatic dump to login.
      if (mounted) {
        final provider = Provider.of<AuthProvider>(context, listen: false);
        if (!provider.isLoggedIn) {
          setState(() => _needsRetry = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo - no complex animation
                const LogoWidget(width: 280, height: 100),

                const SizedBox(height: 40),

                // Hospital name
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Excellence in Healthcare',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 80),

                // Loading indicator / retry prompt (bug #26)
                if (_needsRetry)
                  Column(
                    children: [
                      Text(
                        'Connection problem',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'We couldn\'t verify your session. Check your '
                          'internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _initializeApp,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login),
                        child: Text(
                          'Sign in instead',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
