import 'dart:io';

import 'package:utopia_http/utopia_http.dart';
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Simple cluster example for Utopia HTTP with load balancing

  // Check if this is a worker process
  final processId =
      int.tryParse(Platform.environment['UTOPIA_PROCESS_ID'] ?? '');
  final workerPort =
      int.tryParse(Platform.environment['UTOPIA_WORKER_PORT'] ?? '');

  if (processId != null && workerPort != null) {
    // Worker process: start HTTP server
    await startHttpServer(workerPort);
  } else {
    // Main process: start cluster
    await startCluster();
  }
}

Future<void> startHttpServer(int port) async {
  final app = Http(ShelfServer(InternetAddress.anyIPv4, port));

  app.get('/').inject('response').action((Response response) {
    response.json({
      'message': 'Hello from Utopia HTTP cluster!',
      'worker_pid': pid,
      'worker_port': port,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return response;
  });

  app.get('/ping').inject('response').action((Response response) {
    response.text('pong from worker $pid');
    return response;
  });

  await app.start();
  print('✅ Worker $pid ready on port $port');
}

Future<void> startCluster() async {
  print('🚀 Starting Utopia HTTP cluster...');

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

  await cluster.start();
}
