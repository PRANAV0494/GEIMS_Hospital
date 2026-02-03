import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'database_service.dart';

/// Represents a queued write operation
class QueuedOperation {
  final String id;
  final String type; // 'addPatient', 'updatePatient', 'addVitals', etc.
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': jsonEncode(data),
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory QueuedOperation.fromMap(Map<String, dynamic> map) {
    return QueuedOperation(
      id: map['id'],
      type: map['type'],
      data: jsonDecode(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
      retryCount: map['retryCount'],
    );
  }
}

/// Service to queue write operations when offline and sync when online
class OfflineQueueService {
  // ignore: unused_field - Reserved for future offline sync implementation
  final DatabaseService _databaseService;
  final Logger _logger;

  Database? _database;
  Timer? _syncTimer;
  bool _isSyncing = false;

  OfflineQueueService({
    required DatabaseService databaseService,
    required Logger logger,
  }) : _databaseService = databaseService,
       _logger = logger;

  /// Initialize the SQLite database for queue
  Future<void> initialize() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'offline_queue.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE queue (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            retryCount INTEGER DEFAULT 0
          )
        ''');
      },
    );

    _logger.i('📦 Offline queue initialized');

    // Start periodic sync (every 30 seconds)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processPendingOperations();
    });
  }

  /// Add operation to queue
  Future<void> enqueue(QueuedOperation operation) async {
    if (_database == null) return;

    await _database!.insert(
      'queue',
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _logger.i('➕ Queued operation: ${operation.type}');
  }

  /// Get all pending operations
  Future<List<QueuedOperation>> getPendingOperations() async {
    if (_database == null) return [];

    final List<Map<String, dynamic>> maps = await _database!.query(
      'queue',
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => QueuedOperation.fromMap(map)).toList();
  }

  /// Process all pending operations
  Future<void> processPendingOperations() async {
    if (_isSyncing || _database == null) return;

    _isSyncing = true;
    final operations = await getPendingOperations();

    if (operations.isEmpty) {
      _isSyncing = false;
      return;
    }

    _logger.i('🔄 Processing ${operations.length} queued operations...');

    for (final operation in operations) {
      try {
        final success = await _executeOperation(operation);

        if (success) {
          await _removeFromQueue(operation.id);
          _logger.i('✅ Processed: ${operation.type}');
        } else {
          // Increment retry count
          await _incrementRetryCount(operation.id);

          // Remove if retried too many times (max 5)
          if (operation.retryCount >= 5) {
            await _removeFromQueue(operation.id);
            _logger.e('❌ Failed after 5 retries: ${operation.type}');
          }
        }
      } catch (e) {
        _logger.e('Error processing operation: $e');
      }
    }

    _isSyncing = false;
  }

  /// Execute a queued operation
  Future<bool> _executeOperation(QueuedOperation operation) async {
    try {
      switch (operation.type) {
        case 'addPatient':
          // TODO: Implement based on your data structure
          return false;
        case 'updatePatient':
          // TODO: Implement
          return false;
        case 'addVitals':
          // TODO: Implement
          return false;
        case 'addMedication':
          // TODO: Implement
          return false;
        case 'sendMessage':
          // TODO: Implement
          return false;
        default:
          _logger.w('Unknown operation type: ${operation.type}');
          return false;
      }
    } catch (e) {
      _logger.e('Failed to execute operation: $e');
      return false;
    }
  }

  /// Remove operation from queue
  Future<void> _removeFromQueue(String id) async {
    await _database?.delete('queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Increment retry count
  Future<void> _incrementRetryCount(String id) async {
    await _database?.rawUpdate(
      'UPDATE queue SET retryCount = retryCount + 1 WHERE id = ?',
      [id],
    );
  }

  /// Get queue size
  Future<int> getQueueSize() async {
    if (_database == null) return 0;
    final result = await _database!.rawQuery('SELECT COUNT(*) FROM queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all queued operations (use with caution)
  Future<void> clearQueue() async {
    await _database?.delete('queue');
    _logger.w('🗑️ Queue cleared');
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _database?.close();
    _logger.i('📦 Offline queue disposed');
  }
}
