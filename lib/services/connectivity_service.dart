import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  final _connectionStatusController = StreamController<bool>.broadcast();
  bool _isConnected = true;

  /// Stream of connection status changes
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  
  /// Current connection status
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isConnected = !result.contains(ConnectivityResult.none);
    
    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasConnected = _isConnected;
      _isConnected = !results.contains(ConnectivityResult.none);
      
      if (wasConnected != _isConnected) {
        _connectionStatusController.add(_isConnected);
        debugPrint('🌐 Connectivity changed: ${_isConnected ? "ONLINE" : "OFFLINE"}');
      }
    });
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _connectionStatusController.close();
  }
}
