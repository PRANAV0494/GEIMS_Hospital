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
import 'providers/patient_provider.dart';
import 'providers/message_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Disable reCAPTCHA verification for development (emulators/testing)
    // IMPORTANT: Remove this in production or configure App Check properly
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );

    // Enable Firestore persistence for offline support and caching
    // Limit cache to 100MB to prevent memory bloat
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB limit
    );

    debugPrint('✅ Firebase initialized successfully with persistence');
    debugPrint('⚠️ reCAPTCHA disabled for development');
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  // Initialize service locator and all services
  try {
    await setupServiceLocator();
    debugPrint('✅ Service locator initialized');
  } catch (e) {
    debugPrint('❌ Service locator initialization error: $e');
  }

  runApp(const GraphicEraHospitalApp());
}

class GraphicEraHospitalApp extends StatelessWidget {
  const GraphicEraHospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
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
