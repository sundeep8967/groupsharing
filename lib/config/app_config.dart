import 'environment.dart';

/// Application configuration and constants
class AppConfig {
  // Private constructor
  AppConfig._();

  // Location settings
  static const Duration locationUpdateInterval = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(seconds: 60);
  static const double locationAccuracyThreshold = 10.0; // meters

  // UI settings
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 250);
  static const int maxRetryAttempts = 3;

  // Cache settings
  static const Duration imageCacheExpiry = Duration(hours: 24);
  static const Duration mapTileCacheExpiry = Duration(days: 7);
  static const int maxCacheSize = 100; // MB

  // Network settings
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // Firebase settings
  static const Duration firestoreTimeout = Duration(seconds: 15);
  static const int maxFirestoreRetries = 3;

  // Friend code settings
  static const int friendCodeLength = 6;
  static const String friendCodeCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  // Deep link settings
  static const String deepLinkScheme = 'groupsharing';
  static const String addFriendHost = 'addfriend';

  // Validation methods
  static bool isValidFriendCode(String code) {
    return code.length == friendCodeLength &&
           code.split('').every((char) => friendCodeCharacters.contains(char));
  }

  /// Gets configuration based on environment
  static Map<String, dynamic> getConfig() {
    return {
      'environment': Environment.isDebugMode ? 'debug' : 'production',
      'apiKey': Environment.getMapApiKey(),
      'projectId': Environment.firebaseProjectId,
      'enableCrashlytics': Environment.enableCrashlytics,
      'enablePerformance': Environment.enablePerformanceMonitoring,
      'verboseLogging': Environment.enableVerboseLogging,
    };
  }
}