import 'dart:async';
import 'dart:isolate';

/// Handler for CPU-intensive work that can be offloaded to isolates
typedef CpuIntensiveHandler<T> = T Function(dynamic data);

/// Manages CPU-intensive work delegation to isolates for high-performance computing
class HybridProcessor {
  final int _isolatePoolSize;
  final List<SendPort> _isolatePool = [];
  final List<bool> _isolateAvailable = [];
  int _nextIsolate = 0;

  HybridProcessor({int isolatePoolSize = 2})
      : _isolatePoolSize = isolatePoolSize;

  /// Initialize the isolate pool
  Future<void> initialize() async {
    print(
        '[HybridProcessor] Initializing $_isolatePoolSize isolates for CPU work');

    for (int i = 0; i < _isolatePoolSize; i++) {
      await _createIsolate();
    }

    print('[HybridProcessor] Isolate pool ready');
  }

  /// Create a single compute isolate
  Future<void> _createIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(_isolateEntryPoint, receivePort.sendPort);

    final sendPort = await receivePort.first as SendPort;
    _isolatePool.add(sendPort);
    _isolateAvailable.add(true);
  }

  /// Process CPU-intensive work using available isolates
  Future<T> processWork<T>(
    CpuIntensiveHandler<T> handler,
    dynamic data,
  ) async {
    // Find available isolate
    final isolateIndex = _getAvailableIsolate();
    if (isolateIndex == -1) {
      // No isolates available, run on main thread
      return handler(data);
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

      return result as T;
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
