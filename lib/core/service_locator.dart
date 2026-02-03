import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';

final getIt = GetIt.instance;

/// Initialize all services with dependency injection
/// Call this once at app startup
Future<void> setupServiceLocator() async {
  // Logger
  getIt.registerLazySingleton<Logger>(() => Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 50,
          colors: true,
          printEmojis: true,
        ),
      ));

  // Core Services (Singletons)
  getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  
  // Connectivity Service
  getIt.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  
  // Offline Queue Service (depends on DatabaseService)
  getIt.registerLazySingleton<OfflineQueueService>(
    () => OfflineQueueService(
      databaseService: getIt<DatabaseService>(),
      logger: getIt<Logger>(),
    ),
  );

  // Initialize services that need async setup
  await getIt<ConnectivityService>().initialize();
  await getIt<OfflineQueueService>().initialize();
}

/// Clean up all services on app shutdown
Future<void> disposeServiceLocator() async {
  await getIt<OfflineQueueService>().dispose();
  await getIt<ConnectivityService>().dispose();
  await getIt.reset();
}
