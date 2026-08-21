import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

final getIt = GetIt.instance;

/// Initialize services with dependency injection.
/// Call this once at app startup.
///
/// Note: the former OfflineQueueService / ConnectivityService scaffolding was
/// removed (bug #14/#39): every replay handler was a TODO stub, nothing ever
/// called enqueue(), and Firestore's native offline persistence
/// (persistenceEnabled: true in main.dart) already queues and replays offline
/// writes safely - the custom queue would have deleted failed ops after 5
/// retries (silent data loss) had it ever been wired up.
Future<void> setupServiceLocator() async {
  // Logger
  getIt.registerLazySingleton<Logger>(
    () => Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 50,
        colors: true,
        printEmojis: true,
      ),
    ),
  );

  // Core Services (Singletons)
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<AuthService>(() => AuthService());
}

/// Clean up all services on app shutdown
Future<void> disposeServiceLocator() async {
  await getIt.reset();
}
