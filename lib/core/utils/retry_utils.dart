import 'dart:async';

class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffFactor;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffFactor = 2.0,
  });
}

Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
  String? operationName,
  bool Function(dynamic error)? shouldRetry,
}) async {
  int attempts = 0;
  Duration delay = config.initialDelay;

  while (attempts < config.maxAttempts) {
    attempts++;
    
    try {
      return await operation();
    } catch (error, stackTrace) {
      final shouldRetryNow = shouldRetry?.call(error) ?? true;
      
      if (attempts >= config.maxAttempts || !shouldRetryNow) {
        print('❌ [Retry] ${operationName ?? 'Operation'} failed after $attempts attempts: $error');
        print('Stack trace: $stackTrace');
        rethrow;
      }
      
      print('⚠️ [Retry] ${operationName ?? 'Operation'} attempt $attempts failed: $error');
      print('Retrying in ${delay.inMilliseconds}ms...');
      
      await Future.delayed(delay);
      
      delay = Duration(
        milliseconds: (delay.inMilliseconds * config.backoffFactor).toInt().clamp(
          config.initialDelay.inMilliseconds,
          config.maxDelay.inMilliseconds,
        ),
      );
    }
  }
  
  throw StateError('Unreachable code');
}

bool shouldRetryOnNetworkError(dynamic error) {
  final errorString = error.toString().toLowerCase();
  
  return errorString.contains('network') ||
      errorString.contains('timeout') ||
      errorString.contains('connection') ||
      errorString.contains('socket') ||
      errorString.contains('failed host lookup') ||
      errorString.contains('connection refused');
}

bool shouldRetryOnServerError(dynamic error) {
  final errorString = error.toString().toLowerCase();
  
  return errorString.contains('500') ||
      errorString.contains('502') ||
      errorString.contains('503') ||
      errorString.contains('504');
}
