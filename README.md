# Utopia Load Balancer

Load balancer and multi-process scaling for Utopia HTTP framework.

## Overview

This package provides advanced scaling strategies that were moved out of the core `utopia_http` package to keep it simple and focused. If you need multi-process scaling or load balancing, use this package in addition to `utopia_http`.

## Features

- **Cluster Mode**: Multiple processes on different ports with load balancing
- **Hybrid Mode**: Single process with CPU-intensive work offloaded to isolates
- **Load Balancer**: Built-in HTTP proxy with multiple strategies
- **Auto-restart**: Automatic process restart on failures

## Usage

### Basic Cluster Setup

```dart
import 'package:utopia_http/utopia_http.dart';
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  final app = Http(
    ShelfServer(InternetAddress.anyIPv4, 8080),
  );

  // Define your routes
  app.get('/').inject('response').action((Response response) {
    response.text('Hello from worker process!');
    return response;
  });

  // Use cluster manager for multi-process scaling
  final clusterConfig = ClusterConfig(
    processes: 4,
    basePort: 8080,
    enableLoadBalancer: true,
    loadBalancerPort: 80,
    strategy: LoadBalancingStrategy.roundRobin,
  );

  final clusterManager = ClusterManager(
    clusterConfig,
    Platform.executableArguments,
  );

  await clusterManager.start();
}
```

### Hybrid Processing

```dart
import 'package:utopia_http/utopia_http.dart';
import 'package:utopia_loadbalancer/utopia_loadbalancer.dart';

void main() async {
  final app = Http(
    ShelfServer(InternetAddress.anyIPv4, 8080),
  );

  final hybridProcessor = HybridRequestProcessor(isolatePoolSize: 4);
  await hybridProcessor.initialize();

  app.get('/cpu-intensive').inject('request').action((Request request) async {
    // Offload CPU work to isolates
    return await hybridProcessor.processRequest(
      request,
      (data) {
        // CPU-intensive computation
        var result = 0;
        for (int i = 0; i < data['iterations']; i++) {
          result += i;
        }
        return result;
      },
      {'iterations': 100000000},
    );
  });

  await app.start();
}
```

## Scaling Strategies

### 1. Cluster Mode
- **Use case**: High traffic applications
- **Benefits**: True multi-core utilization, fault tolerance
- **Trade-offs**: Higher memory usage, more complex deployment

### 2. Hybrid Mode  
- **Use case**: Mixed workloads (I/O + CPU)
- **Benefits**: Non-blocking I/O with CPU isolation
- **Trade-offs**: Limited by Dart isolate communication overhead

### 3. Load Balancing Strategies

- **Round Robin**: Evenly distributes requests
- **Least Connections**: Routes to least busy worker
- **Random**: Random distribution

## Architecture

The package is organized as follows:

- `scaling_config.dart` - Configuration classes for scaling modes
- `cluster_manager.dart` - Multi-process orchestration
- `load_balancer.dart` - HTTP proxy and request distribution
- `hybrid_processor.dart` - Isolate pool for CPU-intensive work

## When to Use This Package

Use `utopia_loadbalancer` when:

- You need to handle high traffic (1000+ concurrent users)
- You have CPU-intensive operations that would block the event loop
- You need fault tolerance and auto-restart capabilities
- You want to utilize multiple CPU cores effectively

For simple applications, the core `utopia_http` package with single-process async handling is sufficient and much simpler to deploy and debug.
