import 'dart:async';

/// Utility class to manage stream subscriptions and prevent memory leaks
class StreamManager {
  final List<StreamSubscription> _subscriptions = [];

  /// Add a stream subscription to be managed
  void add(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Listen to a stream and automatically manage the subscription
  StreamSubscription<T> listen<T>(
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Pause all managed subscriptions
  void pauseAll() {
    for (final subscription in _subscriptions) {
      subscription.pause();
    }
  }

  /// Resume all managed subscriptions
  void resumeAll() {
    for (final subscription in _subscriptions) {
      subscription.resume();
    }
  }

  /// Cancel all managed subscriptions
  Future<void> cancelAll() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Get the number of active subscriptions
  int get activeCount => _subscriptions.length;

  /// Dispose of all resources
  Future<void> dispose() async {
    await cancelAll();
  }
}

