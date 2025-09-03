import 'dart:io';

/// Server scaling strategies
enum ScalingMode {
  /// Single process, async request handling (default)
  single,

  /// Multiple processes on different ports
  cluster,

  /// Single process with CPU-intensive work offloaded to isolates
  hybrid,
}

/// Configuration for multi-process scaling
class ClusterConfig {
  /// Number of processes to spawn
  final int processes;

  /// Starting port (each process gets port + index)
  final int basePort;

  /// Whether to start a built-in load balancer
  final bool enableLoadBalancer;

  /// Load balancer port (if enabled)
  final int? loadBalancerPort;

  /// Load balancing strategy
  final LoadBalancingStrategy strategy;

  const ClusterConfig({
    this.processes = 4, // Default to 4 processes, can be overridden
    required this.basePort,
    this.enableLoadBalancer = false,
    this.loadBalancerPort,
    this.strategy = LoadBalancingStrategy.roundRobin,
  });
}

/// Load balancing strategies
enum LoadBalancingStrategy {
  roundRobin,
  leastConnections,
  random,
}

/// Process information for cluster mode
class ProcessInfo {
  final int id;
  final int port;
  final Process? process;
  final bool isMain;

  const ProcessInfo({
    required this.id,
    required this.port,
    this.process,
    this.isMain = false,
  });
}
