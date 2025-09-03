# Utopia Load Balancer

A high-performance, generic load balancer and multi-process scaling library for Dart applications. This package provides tools for distributing load across multiple processes, managing clusters, and offloading CPU-intensive work to isolates.

## Features

- **Multi-Process Clustering**: Spawn multiple worker processes for better CPU utilization
- **Load Balancing**: Built-in HTTP load balancer with multiple strategies
- **Hybrid Processing**: Offload CPU-intensive tasks to isolate pools
- **Zero Dependencies**: Pure Dart implementation with no external dependencies
- **Framework Agnostic**: Works with any Dart HTTP server implementation

## Load Balancing Strategies

- **Round Robin**: Distributes requests evenly across workers
- **Least Connections**: Routes to the worker with fewest active connections  
- **Random**: Randomly selects workers for each request

## Quick Start

### 1. Basic Cluster Setup

```dart
import 'dart:io';
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Check if this is a worker process
  final processId = ClusterManager.processId;
  final workerPort = ClusterManager.workerPort;

  if (processId != null && workerPort != null) {
    // Worker process: start your HTTP server
    await startWorker(workerPort);
  } else {
    // Main process: start cluster
    await startCluster();
  }
}

Future<void> startWorker(int port) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  
  await for (HttpRequest request in server) {
    // Handle your requests here
    request.response.write('Hello from worker $pid on port $port');
    await request.response.close();
  }
}

Future<void> startCluster() async {
  final config = ClusterConfig(
    processes: 4,                           // Number of worker processes
    basePort: 8080,                         // Starting port for workers
    enableLoadBalancer: true,               // Enable built-in load balancer
    loadBalancerPort: 3000,                 // Load balancer port
    strategy: LoadBalancingStrategy.roundRobin,
  );

  final cluster = ClusterManager(config, [Platform.script.toFilePath()]);
  await cluster.start();
}
```

### 2. Standalone Load Balancer

```dart
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Define your backend servers
  final backends = [
    ProcessInfo(id: 0, port: 8081),
    ProcessInfo(id: 1, port: 8082), 
    ProcessInfo(id: 2, port: 8083),
  ];

  final config = ClusterConfig(
    processes: backends.length,
    basePort: 8081,
    loadBalancerPort: 3000,
    strategy: LoadBalancingStrategy.leastConnections,
  );

  final loadBalancer = LoadBalancer(config, backends);
  await loadBalancer.start();
}
```

### 3. Hybrid Processing (CPU-Intensive Tasks)

```dart
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  // Initialize isolate pool for CPU-intensive work
  final processor = HybridProcessor(isolatePoolSize: 3);
  await processor.initialize();

  // Use processor for heavy computations
  final result = await processor.processWork<int>(
    (data) {
      // CPU-intensive task runs in isolate
      final n = data as int;
      return fibonacci(n);
    },
    40, // Calculate fibonacci(40)
  );

  print('Fibonacci result: $result');
}

int fibonacci(int n) {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}
```

## Configuration Options

### ClusterConfig

```dart
ClusterConfig({
  int processes = 4,                    // Number of worker processes
  required int basePort,                // Starting port for workers (port + index)
  bool enableLoadBalancer = false,      // Enable built-in load balancer
  int? loadBalancerPort,               // Load balancer port (if enabled)
  LoadBalancingStrategy strategy = LoadBalancingStrategy.roundRobin,
})
```

### Load Balancing Strategies

- `LoadBalancingStrategy.roundRobin` - Distributes requests in round-robin fashion
- `LoadBalancingStrategy.leastConnections` - Routes to worker with fewest connections
- `LoadBalancingStrategy.random` - Randomly selects workers

## Examples

The `example/` directory contains two essential examples:

- **`cluster_example.dart`** - Multi-process clustering with load balancing
- **`hybrid_processor_example.dart`** - CPU-intensive processing with isolates

### Running Examples

```bash
# Multi-process cluster with load balancing
dart run example/cluster_example.dart

# Hybrid processing server with isolates
dart run example/hybrid_processor_example.dart

# Standalone load balancer
dart run example/simple_load_balancer.dart
```

## API Reference

### ClusterManager

Manages multiple worker processes and optional load balancer.

```dart
final cluster = ClusterManager(config, [Platform.script.toFilePath()]);
await cluster.start();
```

**Static Methods:**
- `ClusterManager.isClusterMode` - Check if running in cluster mode
- `ClusterManager.isWorker` - Check if current process is a worker
- `ClusterManager.workerPort` - Get worker port for current process
- `ClusterManager.processId` - Get process ID for current process

### LoadBalancer

HTTP load balancer for distributing requests across multiple backends.

```dart
final loadBalancer = LoadBalancer(config, workers);
await loadBalancer.start();
```

### HybridProcessor

Manages isolate pools for CPU-intensive work.

```dart
final processor = HybridProcessor(isolatePoolSize: 3);
await processor.initialize();

final result = await processor.processWork<T>(handler, data);
```

## Performance Considerations

1. **Process Count**: Generally set to the number of CPU cores available
2. **Isolate Pool Size**: For CPU-intensive work, 2-4 isolates per core
3. **Load Balancing Strategy**: 
   - Use `roundRobin` for uniform requests
   - Use `leastConnections` for variable request processing times
   - Use `random` for simple distribution

## Platform Support

- ✅ Linux
- ✅ macOS  
- ✅ Windows
- ✅ Docker containers

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
