import 'dart:async';
import 'dart:isolate';

import 'package:utopia_http/src/request.dart';
import 'package:utopia_http/src/response.dart';

/// Handler for CPU-intensive work that can be offloaded to isolates
typedef CpuIntensiveHandler<T> = T Function(dynamic data);

/// Determines if a request should be handled by an isolate
typedef IsolatePredicate = bool Function(Request request);

/// Manages CPU-intensive work delegation to isolates
class HybridRequestProcessor {
  final int _isolatePoolSize;
  final List<SendPort> _isolatePool = [];
  final List<bool> _isolateAvailable = [];
  int _nextIsolate = 0;

  HybridRequestProcessor({int isolatePoolSize = 2})
      : _isolatePoolSize = isolatePoolSize;

  /// Initialize the isolate pool
  Future<void> initialize() async {
    print('[Hybrid] Initializing $_isolatePoolSize isolates for CPU work');

    for (int i = 0; i < _isolatePoolSize; i++) {
      await _createIsolate();
    }

    print('[Hybrid] Isolate pool ready');
  }

  /// Create a single compute isolate
  Future<void> _createIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntryPoint, receivePort.sendPort);

    final sendPort = await receivePort.first as SendPort;
    _isolatePool.add(sendPort);
    _isolateAvailable.add(true);
  }

  /// Process request with CPU-intensive work offloaded to isolates
  Future<Response> processRequest<T>(
    Request request,
    CpuIntensiveHandler<T> handler,
    dynamic data,
  ) async {
    // Find available isolate
    final isolateIndex = _getAvailableIsolate();
    if (isolateIndex == -1) {
      // No isolates available, run on main thread
      final result = handler(data);
      return Response(result.toString());
    }

    try {
      _isolateAvailable[isolateIndex] = false;

      // Send work to isolate
      final receivePort = ReceivePort();
      _isolatePool[isolateIndex].send({
        'handler': handler,
        'data': data,
        'replyPort': receivePort.sendPort,
      });

      // Wait for result
      final result = await receivePort.first;

      if (result is Map && result['error'] != null) {
        throw Exception('Isolate error: ${result['error']}');
      }

      return Response(result.toString());
    } finally {
      _isolateAvailable[isolateIndex] = true;
    }
  }

  /// Get next available isolate index
  int _getAvailableIsolate() {
    for (int i = 0; i < _isolatePoolSize; i++) {
      final index = (_nextIsolate + i) % _isolatePoolSize;
      if (_isolateAvailable[index]) {
        _nextIsolate = (index + 1) % _isolatePoolSize;
        return index;
      }
    }
    return -1; // No available isolates
  }

  /// Shutdown isolate pool
  Future<void> shutdown() async {
    print('[Hybrid] Shutting down isolate pool');

    for (final sendPort in _isolatePool) {
      sendPort.send({'shutdown': true});
    }

    _isolatePool.clear();
    _isolateAvailable.clear();
  }

  /// Entry point for compute isolates
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is Map) {
        if (message['shutdown'] == true) {
          receivePort.close();
          return;
        }

        try {
          final handler = message['handler'] as Function;
          final data = message['data'];
          final replyPort = message['replyPort'] as SendPort;

          final result = handler(data);
          replyPort.send(result);
        } catch (e) {
          final replyPort = message['replyPort'] as SendPort;
          replyPort.send({'error': e.toString()});
        }
      }
    });
  }
}
