import 'dart:io';

import 'package:utopia_http/utopia_http.dart';
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Check if this is a worker process
  final processId =
      int.tryParse(Platform.environment['UTOPIA_PROCESS_ID'] ?? '');
  final workerPort =
      int.tryParse(Platform.environment['UTOPIA_WORKER_PORT'] ?? '');

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
  final app = Http(ShelfServer(InternetAddress.anyIPv4, port));

  // Define your routes
  app.get('/').inject('response').action((Response response) {
    response.text('Hello from worker process! PID: $pid, Port: $port');
    return response;
  });

  app.get('/health').inject('response').action((Response response) {
    response.json({
      'status': 'healthy',
      'pid': pid,
      'port': port,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return response;
  });

  await app.start();
  print('Worker $pid listening on port $port');
}

/// Start the cluster manager
Future<void> startCluster() async {
  print('Starting cluster manager...');

  // Use cluster manager for multi-process scaling
  final clusterConfig = ClusterConfig(
    processes: 4,
    basePort: 8080,
    enableLoadBalancer: true,
    loadBalancerPort: 3000,
    strategy: LoadBalancingStrategy.roundRobin,
  );

  final clusterManager = ClusterManager(
    clusterConfig,
    [Platform.script.toFilePath()],
  );

  await clusterManager.start();
}
