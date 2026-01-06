import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;

/// Enhanced retry service with exponential backoff and circuit breaker
class RetryService {
  static const String _tag = 'RetryService';
  
  /// Execute operation with retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;
    
    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        developer.log('[$_tag] ${operationName ?? 'Operation'} attempt $attempt/$maxAttempts');
        
        final result = await operation();
        
        if (attempt > 1) {
          developer.log('[$_tag] ${operationName ?? 'Operation'} succeeded on attempt $attempt');
        }
        
        return result;
        
      } catch (error) {
        developer.log('[$_tag] ${operationName ?? 'Operation'} failed on attempt $attempt: $error');
        
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          developer.log('[$_tag] Error not retryable, throwing immediately');
          rethrow;
        }
        
        // If this was the last attempt, throw the error
        if (attempt >= maxAttempts) {
          developer.log('[$_tag] Max attempts reached, throwing error');
          rethrow;
        }
        
        // Wait before retrying with exponential backoff
        developer.log('[$_tag] Waiting ${currentDelay.inMilliseconds}ms before retry...');
        await Future.delayed(currentDelay);
        
        // Calculate next delay with jitter
        currentDelay = Duration(
          milliseconds: min(
            (currentDelay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
        
        // Add jitter to prevent thundering herd
        final jitter = Random().nextDouble() * 0.1; // 10% jitter
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * (1 + jitter)).round(),
        );
      }
    }
    
    throw Exception('This should never be reached');
  }
  
  /// Default retry condition for network operations
  static bool shouldRetryNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Retry on network errors
    if (errorStr.contains('network') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      return true;
    }
    
    // Retry on server errors (5xx)
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }
    
    // Don't retry on client errors (4xx)
    if (errorStr.contains('400') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('404')) {
      return false;
    }
    
    // Default: retry
    return true;
  }
  
  /// Retry specifically for Firebase operations
  static Future<T> retryFirebaseOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    return executeWithRetry(
      operation,
      maxAttempts: 3,
      initialDelay: const Duration(milliseconds: 500),
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 10),
      shouldRetry: shouldRetryNetworkError,
      operationName: operationName ?? 'Firebase operation',
    );
  }
  
  /// Retry for location operations
  static Future<T> retryLocationOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    return executeWithRetry(
      operation,
      maxAttempts: 5,
      initialDelay: const Duration(seconds: 1),
      backoffMultiplier: 1.5,
      maxDelay: const Duration(seconds: 15),
      shouldRetry: (error) {
        final errorStr = error.toString().toLowerCase();
        // Retry on location service errors
        return errorStr.contains('location') ||
               errorStr.contains('gps') ||
               errorStr.contains('permission') ||
               shouldRetryNetworkError(error);
      },
      operationName: operationName ?? 'Location operation',
    );
  }
}

/// Circuit breaker pattern for preventing cascading failures
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitBreakerState _state = CircuitBreakerState.closed;
  
  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.resetTimeout = const Duration(minutes: 1),
  });
  
  /// Execute operation through circuit breaker
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitBreakerState.halfOpen;
        developer.log('[CircuitBreaker] $name: Attempting reset (half-open)');
      } else {
        throw CircuitBreakerOpenException('Circuit breaker $name is open');
      }
    }
    
    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return result;
      
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }
  
  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    developer.log('[CircuitBreaker] $name: Success, circuit closed');
  }
  
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      developer.log('[CircuitBreaker] $name: Circuit opened after $failureThreshold failures');
    }
  }
  
  bool _shouldAttemptReset() {
    return _lastFailureTime != null &&
           DateTime.now().difference(_lastFailureTime!) > resetTimeout;
  }
  
  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;
}

enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);
  
  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// Extension for easy retry on Future operations
extension FutureRetry<T> on Future<T> {
  Future<T> withRetry({
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String? operationName,
  }) {
    return RetryService.executeWithRetry(
      () => this,
      maxAttempts: maxAttempts,
      initialDelay: initialDelay,
      operationName: operationName,
    );
  }
  
  Future<T> withFirebaseRetry({String? operationName}) {
    return RetryService.retryFirebaseOperation(
      () => this,
      operationName: operationName,
    );
  }
  
  Future<T> withLocationRetry({String? operationName}) {
    return RetryService.retryLocationOperation(
      () => this,
      operationName: operationName,
    );
  }
}