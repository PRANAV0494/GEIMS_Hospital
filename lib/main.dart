import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/service_locator.dart';
import 'config/app_theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Disable reCAPTCHA/app verification ONLY in debug builds for emulator
    // testing. Shipping this enabled in release lets automated abuse through
    // the phone/SMS verification path (bug #13 - previously unconditional).
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    // Enable Firestore persistence for offline support and caching.
    // Limit cache to 100MB to prevent memory bloat.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB limit
    );

    debugPrint('✅ Firebase initialized successfully with persistence');
  } catch (e, st) {
    // Bug #26 companion: a swallowed init failure used to leave a spinner
    // forever downstream. Log loudly; splash screen surfaces the failure to
    // the user with a retry instead of silently dumping them at login.
    debugPrint('❌ Firebase initialization error: $e\n$st');
  }

  // Initialize service locator and all services
  try {
    await setupServiceLocator();
    debugPrint('✅ Service locator initialized');
  } catch (e, st) {
    debugPrint('❌ Service locator initialization error: $e\n$st');
  }

  runApp(const GraphicEraHospitalApp());
}

class GraphicEraHospitalApp extends StatelessWidget {
  const GraphicEraHospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'Graphic Era Hospital',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
