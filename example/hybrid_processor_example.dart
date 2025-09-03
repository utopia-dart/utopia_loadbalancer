import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  print('🚀 Starting hybrid processing example...');

  // Initialize hybrid processor with isolate pool
  final processor = HybridProcessor(isolatePoolSize: 3);
  await processor.initialize();

  // Start simple HTTP server to demonstrate hybrid processing
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 7070);

  print('📊 Server Configuration:');
  print('   Port: 7070');
  print('   Isolate pool size: 3');
  print('   Available endpoints:');
  print('     GET  /                 - Server info');
  print('     POST /compute          - CPU-intensive computation');
  print('     POST /fibonacci        - Fibonacci calculation');
  print('');
  print('🌐 Test with:');
  print('   http://localhost:7070/');
  print('   POST to /compute with {"iterations": 1000000}');
  print('   POST to /fibonacci with {"n": 40}');
  print('');

  await for (HttpRequest request in server) {
    await _handleRequest(request, processor);
  }
}

/// Handle HTTP requests
Future<void> _handleRequest(
    HttpRequest request, HybridProcessor processor) async {
  try {
    final path = request.uri.path;

    // Set CORS headers
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers
        .set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers
        .set('Access-Control-Allow-Headers', 'Content-Type');
    request.response.headers.contentType = ContentType.json;

    // Handle OPTIONS preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    switch (path) {
      case '/':
        await _handleHome(request);
        break;
      case '/compute':
        await _handleCompute(request, processor);
        break;
      case '/fibonacci':
        await _handleFibonacci(request, processor);
        break;
      default:
        await _handleNotFound(request);
    }
  } catch (e) {
    print('Error handling request: $e');
    request.response.statusCode = 500;
    request.response.write(jsonEncode({'error': 'Internal server error: $e'}));
    await request.response.close();
  }
}

/// Handle home route
Future<void> _handleHome(HttpRequest request) async {
  request.response.write(jsonEncode({
    'message': 'Hybrid Processing Server',
    'description': 'CPU-intensive tasks are offloaded to isolates',
    'server_pid': pid,
    'endpoints': {
      '/': 'Server info',
      '/compute': 'POST - CPU-intensive computation',
      '/fibonacci': 'POST - Fibonacci calculation',
    },
    'timestamp': DateTime.now().toIso8601String(),
  }));
  await request.response.close();
}

/// Handle compute-intensive task
Future<void> _handleCompute(
    HttpRequest request, HybridProcessor processor) async {
  if (request.method != 'POST') {
    request.response.statusCode = 405;
    request.response.write(jsonEncode({'error': 'Method not allowed'}));
    await request.response.close();
    return;
  }

  // Read request body
  final bodyBytes =
      await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  final body = utf8.decode(bodyBytes);
  final data = jsonDecode(body) as Map<String, dynamic>;
  final iterations = data['iterations'] as int? ?? 100000;

  final stopwatch = Stopwatch()..start();

  // Process using hybrid processor (may use isolates)
  final result = await processor.processWork<int>(
    _computeIntensiveTask,
    iterations,
  );

  stopwatch.stop();

  request.response.write(jsonEncode({
    'result': result,
    'iterations': iterations,
    'execution_time_ms': stopwatch.elapsedMilliseconds,
    'server_pid': pid,
    'timestamp': DateTime.now().toIso8601String(),
  }));
  await request.response.close();
}

/// Handle Fibonacci calculation
Future<void> _handleFibonacci(
    HttpRequest request, HybridProcessor processor) async {
  if (request.method != 'POST') {
    request.response.statusCode = 405;
    request.response.write(jsonEncode({'error': 'Method not allowed'}));
    await request.response.close();
    return;
  }

  final bodyBytes =
      await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
  final body = utf8.decode(bodyBytes);
  final data = jsonDecode(body) as Map<String, dynamic>;
  final n = data['n'] as int? ?? 30;

  if (n < 0 || n > 50) {
    request.response.statusCode = 400;
    request.response.write(jsonEncode({'error': 'n must be between 0 and 50'}));
    await request.response.close();
    return;
  }

  final stopwatch = Stopwatch()..start();

  final result = await processor.processWork<int>(
    _fibonacci,
    n,
  );

  stopwatch.stop();

  request.response.write(jsonEncode({
    'fibonacci_number': result,
    'n': n,
    'execution_time_ms': stopwatch.elapsedMilliseconds,
    'server_pid': pid,
    'timestamp': DateTime.now().toIso8601String(),
  }));
  await request.response.close();
}

/// Handle 404 not found
Future<void> _handleNotFound(HttpRequest request) async {
  request.response.statusCode = 404;
  request.response.write(jsonEncode({
    'error': 'Not Found',
    'path': request.uri.path,
    'server_pid': pid,
  }));
  await request.response.close();
}

/// CPU-intensive computation task
int _computeIntensiveTask(dynamic data) {
  final iterations = data as int;
  int result = 0;

  for (int i = 0; i < iterations; i++) {
    result += sqrt(i * i + 1).floor();
  }

  return result;
}

/// Fibonacci calculation (recursive, CPU-intensive for large n)
int _fibonacci(dynamic data) {
  final n = data as int;

  if (n <= 1) return n;
  return _fibonacci(n - 1) + _fibonacci(n - 2);
}
