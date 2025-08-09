/// Environment configuration for the application
/// Handles API keys and environment-specific settings securely
class Environment {
  // Private constructor to prevent instantiation
  Environment._();

  // API Keys - loaded from environment variables or secure storage

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'group-sharing-9d119',
  );

  // App configuration
  static const String appName = 'GroupSharing';
  static const String packageName = 'com.sundeep.groupsharing';

  // Debug settings
  static const bool isDebugMode = bool.fromEnvironment('DEBUG_MODE', defaultValue: false);
  static const bool enableVerboseLogging = bool.fromEnvironment('VERBOSE_LOGGING', defaultValue: false);

  // Feature flags
  static const bool enableCrashlytics = bool.fromEnvironment('ENABLE_CRASHLYTICS', defaultValue: true);
  static const bool enablePerformanceMonitoring = bool.fromEnvironment('ENABLE_PERFORMANCE', defaultValue: true);

  // Validation methods
  static bool get hasValidFirebaseProject => firebaseProjectId.isNotEmpty;

  /// Validates all required environment variables
  static List<String> validateEnvironment() {
    final List<String> errors = [];

    if (!hasValidFirebaseProject) {
      errors.add('FIREBASE_PROJECT_ID is missing or empty');
    }

    return errors;
  }

  // Map API keys not required (using OpenStreetMap tiles). Method removed.
}