import 'dart:async';
import 'package:flutter/material.dart';
import '../core/stream_manager.dart';

/// Base class for StatefulWidgets that need stream management
/// Automatically handles disposal of all managed streams
abstract class ManagedStreamWidget extends StatefulWidget {
  const ManagedStreamWidget({super.key});
}

/// Base state class with built-in stream management
abstract class ManagedStreamState<T extends ManagedStreamWidget>
    extends State<T> {
  final StreamManager _streamManager = StreamManager();

  /// Access to the stream manager
  @protected
  StreamManager get streamManager => _streamManager;

  /// Listen to a stream with automatic cleanup
  @protected
  StreamSubscription<S> listenToStream<S>(
    Stream<S> stream,
    void Function(S) onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    return _streamManager.listen(
      stream,
      onData,
      onError: onError,
      onDone: onDone,
    );
  }

  @override
  void dispose() {
    _streamManager.dispose();
    super.dispose();
  }
}

/// Example usage in a widget:
/// 
/// class MyWidget extends ManagedStreamWidget {
///   const MyWidget({super.key});
///
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends ManagedStreamState<MyWidget> {
///   
///   @override
///   void initState() {
///     super.initState();
///     
///     // Instead of manually managing subscriptions, use listenToStream
///     listenToStream(myDataStream, (data) {
///       setState(() {
///         // Update state
///       });
///     });
///   }
///   
///   // No need to override dispose - automatic cleanup!
/// }
