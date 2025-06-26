import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Commented out - not in dependencies
import '../config/environment.dart';

/// Global error handler for the application
/// Handles uncaught exceptions, Flutter errors, and provides user-friendly error messages
class GlobalErrorHandler {
  static bool _isInitialized = false;
  static final List<AppError> _errorHistory = [];
  static StreamController<AppError>? _errorStreamController;

  /// Initialize the global error handler
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize error stream
    _errorStreamController = StreamController<AppError>.broadcast();

    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = AppError.fromFlutterError(details);
      _handleError(error);
    };

    // Handle async errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      final appError = AppError.fromException(error, stack);
      _handleError(appError);
      return true;
    };

    // Initialize Firebase Crashlytics if enabled
    if (Environment.enableCrashlytics) {
      try {
        // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        
        // Set custom keys for better debugging
        // await FirebaseCrashlytics.instance.setCustomKey('app_version', '1.0.0');
        // await FirebaseCrashlytics.instance.setCustomKey('environment', 
        //   Environment.isDebugMode ? 'debug' : 'production');
        debugPrint('Crashlytics would be initialized here');
      } catch (e) {
        developer.log('Failed to initialize Crashlytics: $e', name: 'ErrorHandler');
      }
    }

    _isInitialized = true;
    developer.log('Global error handler initialized', name: 'ErrorHandler');
  }

  /// Handle an error
  static void _handleError(AppError error) {
    // Add to error history
    _errorHistory.add(error);
    if (_errorHistory.length > 100) {
      _errorHistory.removeAt(0); // Keep only last 100 errors
    }

    // Log to console in debug mode
    if (Environment.isDebugMode || Environment.enableVerboseLogging) {
      developer.log(
        'Error: ${error.message}',
        name: 'ErrorHandler',
        error: error.originalError,
        stackTrace: error.stackTrace,
      );
    }

    // Send to Crashlytics in production
    if (Environment.enableCrashlytics && !Environment.isDebugMode) {
      _sendToCrashlytics(error);
    }

    // Notify error stream listeners
    _errorStreamController?.add(error);
  }

  /// Send error to Firebase Crashlytics
  static void _sendToCrashlytics(AppError error) {
    try {
      if (error.isFatal) {
        // FirebaseCrashlytics.instance.recordError(
        //   error.originalError,
        //   error.stackTrace,
        //   fatal: true,
        //   information: [
        //     'Error Type: ${error.type}',
        //     'Message: ${error.message}',
        //     'User Message: ${error.userMessage}',
        //     'Timestamp: ${error.timestamp}',
        //   ],
        // );
        debugPrint('Would record fatal error to Crashlytics: ${error.message}');
      } else {
        // FirebaseCrashlytics.instance.log(
        //   'Non-fatal error: ${error.type} - ${error.message}',
        // );
        debugPrint('Would log non-fatal error to Crashlytics: ${error.message}');
      }
    } catch (e) {
      developer.log('Failed to send error to Crashlytics: $e', name: 'ErrorHandler');
    }
  }

  /// Report a custom error
  static void reportError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    bool isFatal = false,
  }) {
    final appError = AppError.custom(
      error: error,
      stackTrace: stackTrace,
      context: context,
      additionalData: additionalData,
      isFatal: isFatal,
    );
    _handleError(appError);
  }

  /// Get error stream for listening to errors
  static Stream<AppError>? get errorStream => _errorStreamController?.stream;

  /// Get error history
  static List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  /// Clear error history
  static void clearErrorHistory() {
    _errorHistory.clear();
  }

  /// Dispose resources
  static void dispose() {
    _errorStreamController?.close();
    _errorStreamController = null;
    _isInitialized = false;
  }
}

/// Represents an application error with additional context
class AppError {
  final String message;
  final String userMessage;
  final ErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? context;
  final Map<String, dynamic>? additionalData;
  final bool isFatal;

  AppError({
    required this.message,
    required this.userMessage,
    required this.type,
    required this.originalError,
    this.stackTrace,
    required this.timestamp,
    this.context,
    this.additionalData,
    this.isFatal = false,
  });

  /// Create AppError from FlutterErrorDetails
  factory AppError.fromFlutterError(FlutterErrorDetails details) {
    return AppError(
      message: details.exception.toString(),
      userMessage: _getUserFriendlyMessage(details.exception),
      type: ErrorType.flutter,
      originalError: details.exception,
      stackTrace: details.stack,
      timestamp: DateTime.now(),
      context: details.context?.toString(),
      isFatal: details.silent == false,
    );
  }

  /// Create AppError from general exception
  factory AppError.fromException(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
  }) {
    return AppError(
      message: error.toString(),
      userMessage: _getUserFriendlyMessage(error),
      type: _getErrorType(error),
      originalError: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: context,
      isFatal: _isFatalError(error),
    );
  }

  /// Create custom AppError
  factory AppError.custom({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    bool isFatal = false,
  }) {
    return AppError(
      message: error.toString(),
      userMessage: _getUserFriendlyMessage(error),
      type: ErrorType.custom,
      originalError: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: context,
      additionalData: additionalData,
      isFatal: isFatal,
    );
  }

  /// Get user-friendly error message
  static String _getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Please check your internet connection and try again.';
    }
    
    if (errorString.contains('permission')) {
      return 'Permission required. Please grant the necessary permissions.';
    }
    
    if (errorString.contains('location')) {
      return 'Unable to access location. Please check your location settings.';
    }
    
    if (errorString.contains('firebase') || errorString.contains('firestore')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    
    if (errorString.contains('authentication') || errorString.contains('auth')) {
      return 'Authentication failed. Please sign in again.';
    }

    return 'Something went wrong. Please try again.';
  }

  /// Determine error type
  static ErrorType _getErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('firebase') || errorString.contains('firestore')) {
      return ErrorType.firebase;
    }
    
    if (errorString.contains('network') || errorString.contains('http')) {
      return ErrorType.network;
    }
    
    if (errorString.contains('location') || errorString.contains('geolocator')) {
      return ErrorType.location;
    }
    
    if (errorString.contains('permission')) {
      return ErrorType.permission;
    }

    return ErrorType.unknown;
  }

  /// Check if error is fatal
  static bool _isFatalError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Consider these as non-fatal
    if (errorString.contains('permission') ||
        errorString.contains('network') ||
        errorString.contains('timeout')) {
      return false;
    }

    return true;
  }
}

/// Types of errors that can occur in the application
enum ErrorType {
  flutter,
  firebase,
  network,
  location,
  permission,
  authentication,
  custom,
  unknown,
}

/// Extension to get user-friendly error type names
extension ErrorTypeExtension on ErrorType {
  String get displayName {
    switch (this) {
      case ErrorType.flutter:
        return 'App Error';
      case ErrorType.firebase:
        return 'Service Error';
      case ErrorType.network:
        return 'Network Error';
      case ErrorType.location:
        return 'Location Error';
      case ErrorType.permission:
        return 'Permission Error';
      case ErrorType.authentication:
        return 'Authentication Error';
      case ErrorType.custom:
        return 'Custom Error';
      case ErrorType.unknown:
        return 'Unknown Error';
    }
  }
}