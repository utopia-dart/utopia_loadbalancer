import 'dart:convert';
import 'dart:io';

import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Check if this is a worker process
  final processId = ClusterManager.processId;
  final workerPort = ClusterManager.workerPort;

  if (processId != null && workerPort != null) {
    // This is a worker process - start the HTTP server
    await startWorker(workerPort);
  } else {
    // This is the main process - start the cluster manager
    await startCluster();
  }
}

/// Start a worker HTTP server
Future<void> startWorker(int port) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  print('✅ Worker $pid started on port $port');

  await for (HttpRequest request in server) {
    await _handleRequest(request);
  }
}

/// Handle HTTP requests in the worker
Future<void> _handleRequest(HttpRequest request) async {
  try {
    final path = request.uri.path;

    // Set response headers
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    switch (path) {
      case '/':
        request.response.write(jsonEncode({
          'message': 'Hello from Dart cluster!',
          'worker_pid': pid,
          'worker_port': ClusterManager.workerPort,
          'worker_id': ClusterManager.processId,
          'timestamp': DateTime.now().toIso8601String(),
        }));
        break;

      case '/health':
        request.response.write(jsonEncode({
          'status': 'healthy',
          'pid': pid,
          'port': ClusterManager.workerPort,
          'timestamp': DateTime.now().toIso8601String(),
        }));
        break;

      default:
        request.response.statusCode = 404;
        request.response.write(jsonEncode({
          'error': 'Not Found',
          'path': request.uri.path,
        }));
    }

    await request.response.close();
  } catch (e) {
    print('Worker error: $e');
    request.response.statusCode = 500;
    request.response.write(jsonEncode({'error': 'Internal server error'}));
    await request.response.close();
  }
}

/// Start the cluster manager
Future<void> startCluster() async {
  print('🚀 Starting Dart server cluster...');

  final config = ClusterConfig(
    processes: 4,
    basePort: 8080,
    enableLoadBalancer: true,
    loadBalancerPort: 3000,
    strategy: LoadBalancingStrategy.roundRobin,
  );

  final cluster = ClusterManager(config, [Platform.script.toFilePath()]);

  print('📊 Configuration:');
  print('   Workers: ${config.processes}');
  print('   Base port: ${config.basePort}');
  print('   Load balancer: ${config.enableLoadBalancer}');
  print('   LB port: ${config.loadBalancerPort}');
  print('   Strategy: ${config.strategy}');
  print('');
  print('🌐 Try these endpoints:');
  print('   http://localhost:3000/');
  print('   http://localhost:3000/health');
  print('');

  await cluster.start();
}
