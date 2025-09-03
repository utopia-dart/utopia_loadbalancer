/// A generic load balancer and multi-process scaling library for Dart applications
///
/// This library provides tools for:
/// - Load balancing across multiple processes
/// - Multi-process cluster management
/// - CPU-intensive work delegation to isolates
/// - Different load balancing strategies (round-robin, least connections, random)
library utopia_loadbalancer;

export 'scaling_config.dart';
export 'load_balancer.dart';
export 'cluster_manager.dart';
export 'hybrid_processor.dart';
