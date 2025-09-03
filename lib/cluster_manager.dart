import 'dart:async';
import 'dart:io';

import 'load_balancer.dart';
import 'scaling_config.dart';

/// Manages multiple server processes for cluster mode
class ClusterManager {
  final ClusterConfig config;
  final List<String> dartArgs;
  final List<ProcessInfo> _workers = [];
  LoadBalancer? _loadBalancer;

  ClusterManager(this.config, this.dartArgs);

  /// Start cluster with multiple processes
  Future<void> start() async {
    print('[Cluster] Starting ${config.processes} worker processes');

    // Determine if this is the main process or a worker
    final processId =
        int.tryParse(Platform.environment['UTOPIA_PROCESS_ID'] ?? '');
    final workerPort =
        int.tryParse(Platform.environment['UTOPIA_WORKER_PORT'] ?? '');

    if (processId != null && workerPort != null) {
      // This is a worker process
      print('[Cluster] Starting as worker $processId on port $workerPort');
      return; // Worker will handle its own startup
    }

    // This is the main process - spawn workers
    await _spawnWorkers();

    // Start load balancer if enabled
    if (config.enableLoadBalancer) {
      await _startLoadBalancer();
    } else {
      print('[Cluster] Workers started. Use external load balancer with:');
      for (final worker in _workers) {
        print('[Cluster]   - http://localhost:${worker.port}');
      }

      // Keep main process alive
      await _keepAlive();
    }
  }

  /// Spawn worker processes
  Future<void> _spawnWorkers() async {
    final futures = <Future>[];

    for (int i = 0; i < config.processes; i++) {
      final port = config.basePort + i;
      futures.add(_spawnWorker(i, port));
    }

    await Future.wait(futures);
    print('[Cluster] All ${config.processes} workers started');
  }

  /// Spawn a single worker process
  Future<void> _spawnWorker(int id, int port) async {
    final environment = Map<String, String>.from(Platform.environment);
    environment['UTOPIA_PROCESS_ID'] = id.toString();
    environment['UTOPIA_WORKER_PORT'] = port.toString();
    environment['UTOPIA_SCALING_MODE'] = 'worker';

    final process = await Process.start(
      Platform.executable,
      dartArgs,
      environment: environment,
    );

    // Forward worker output
    process.stdout.listen((data) {
      stdout.add(data);
    });

    process.stderr.listen((data) {
      stderr.add(data);
    });

    // Monitor worker health
    process.exitCode.then((exitCode) {
      print('[Cluster] Worker $id (port $port) exited with code $exitCode');
      _restartWorker(id, port);
    });

    _workers.add(ProcessInfo(
      id: id,
      port: port,
      process: process,
    ));

    print('[Cluster] Worker $id started on port $port');
  }

  /// Restart a failed worker
  Future<void> _restartWorker(int id, int port) async {
    print('[Cluster] Restarting worker $id on port $port');

    // Remove old worker info
    _workers.removeWhere((w) => w.id == id);

    // Wait a bit before restarting
    await Future.delayed(Duration(seconds: 2));

    // Spawn new worker
    await _spawnWorker(id, port);
  }

  /// Start built-in load balancer
  Future<void> _startLoadBalancer() async {
    _loadBalancer = LoadBalancer(config, _workers);
    await _loadBalancer!.start();
  }

  /// Keep main process alive
  Future<void> _keepAlive() async {
    // Set up signal handlers for graceful shutdown
    ProcessSignal.sigint.watch().listen((_) {
      print('[Cluster] Received SIGINT, shutting down...');
      shutdown();
    });

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) {
        print('[Cluster] Received SIGTERM, shutting down...');
        shutdown();
      });
    }

    // Keep alive until shutdown
    final completer = Completer<void>();
    await completer.future;
  }

  /// Shutdown all workers
  void shutdown() async {
    print('[Cluster] Shutting down workers...');

    for (final worker in _workers) {
      worker.process?.kill();
    }

    exit(0);
  }

  /// Check if running in cluster mode
  static bool get isClusterMode =>
      Platform.environment['UTOPIA_SCALING_MODE'] != null;

  /// Check if this is a worker process
  static bool get isWorker =>
      Platform.environment['UTOPIA_SCALING_MODE'] == 'worker';

  /// Get worker port for current process
  static int? get workerPort =>
      int.tryParse(Platform.environment['UTOPIA_WORKER_PORT'] ?? '');

  /// Get process ID for current process
  static int? get processId =>
      int.tryParse(Platform.environment['UTOPIA_PROCESS_ID'] ?? '');
}
