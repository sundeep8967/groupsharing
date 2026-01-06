import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Error Boundary Widget to catch and handle widget crashes gracefully
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? fallbackMessage;
  final VoidCallback? onError;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.fallbackMessage,
    this.onError,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Set up global error handler
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      developer.log('Flutter Error Caught by ErrorBoundary: ${details.exception}');
      developer.log('Stack trace: ${details.stack}');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = details.exception.toString();
        });
      }
      
      widget.onError?.call();
      
      // Call original error handler if it exists
      originalOnError?.call(details);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(context);
    }

    return widget.child;
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.fallbackMessage ?? 
                'We encountered an unexpected error. Please try again.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _errorMessage = null;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                ExpansionTile(
                  title: const Text('Error Details'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Global error handler for async operations
class AsyncErrorHandler {
  static void handleError(Object error, StackTrace stackTrace, {String? context}) {
    developer.log('Async Error${context != null ? ' in $context' : ''}: $error');
    developer.log('Stack trace: $stackTrace');
    
    // You can add crash reporting here (Firebase Crashlytics, Sentry, etc.)
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
}

/// Extension to add error handling to Future operations
extension FutureErrorHandling<T> on Future<T> {
  Future<T> withErrorHandling({String? context}) {
    return catchError((error, stackTrace) {
      AsyncErrorHandler.handleError(error, stackTrace, context: context);
      throw error;
    });
  }
}