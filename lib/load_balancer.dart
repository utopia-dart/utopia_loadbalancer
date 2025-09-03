import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'scaling_config.dart';

/// Simple HTTP load balancer for cluster mode
class LoadBalancer {
  final ClusterConfig config;
  final List<ProcessInfo> _workers;
  int _currentWorkerIndex = 0;
  final Map<ProcessInfo, int> _connectionCounts = {};

  LoadBalancer(this.config, this._workers) {
    for (final worker in _workers) {
      _connectionCounts[worker] = 0;
    }
  }

  /// Start the load balancer
  Future<void> start() async {
    final port = config.loadBalancerPort ?? 8080;

    print('[LoadBalancer] Starting on port $port');
    print('[LoadBalancer] Distributing to ${_workers.length} workers');

    final server = await HttpServer.bind('0.0.0.0', port);

    await for (HttpRequest request in server) {
      _handleRequest(request);
    }
  }

  /// Handle incoming request and proxy to worker
  void _handleRequest(HttpRequest request) async {
    try {
      final worker = _selectWorker();
      await _proxyRequest(request, worker);
    } catch (e) {
      print('[LoadBalancer] Error handling request: $e');
      _sendErrorResponse(request, 502, 'Bad Gateway');
    }
  }

  /// Select worker based on load balancing strategy
  ProcessInfo _selectWorker() {
    switch (config.strategy) {
      case LoadBalancingStrategy.roundRobin:
        final worker = _workers[_currentWorkerIndex];
        _currentWorkerIndex = (_currentWorkerIndex + 1) % _workers.length;
        return worker;

      case LoadBalancingStrategy.leastConnections:
        return _connectionCounts.entries
            .reduce((a, b) => a.value < b.value ? a : b)
            .key;

      case LoadBalancingStrategy.random:
        return _workers[Random().nextInt(_workers.length)];
    }
  }

  /// Proxy request to selected worker
  Future<void> _proxyRequest(HttpRequest request, ProcessInfo worker) async {
    _connectionCounts[worker] = (_connectionCounts[worker] ?? 0) + 1;

    try {
      // Create HTTP client request to worker
      final client = HttpClient();
      final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: worker.port,
        path: request.uri.path,
        query: request.uri.query.isNotEmpty ? request.uri.query : null,
      );

      final clientRequest = await client.openUrl(request.method, uri);

      // Copy headers (except host)
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host') {
          clientRequest.headers.set(name, values);
        }
      });

      // Copy body
      await request.listen((data) {
        clientRequest.add(data);
      }).asFuture();

      // Get response from worker
      final clientResponse = await clientRequest.close();

      // Copy response status and headers
      request.response.statusCode = clientResponse.statusCode;
      clientResponse.headers.forEach((name, values) {
        request.response.headers.set(name, values);
      });

      // Copy response body
      await clientResponse.pipe(request.response);

      client.close();
    } finally {
      _connectionCounts[worker] = (_connectionCounts[worker] ?? 1) - 1;
    }
  }

  /// Send error response
  void _sendErrorResponse(HttpRequest request, int statusCode, String message) {
    try {
      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.text;
      request.response.write(message);
      request.response.close();
    } catch (e) {
      // Ignore errors when sending error response
    }
  }
}
