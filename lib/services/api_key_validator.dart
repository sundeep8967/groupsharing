import 'dart:developer' as developer;
import '../config/api_keys.dart';

/// API Key Validator Service
/// 
/// This service validates all API keys and provides helpful debugging information
/// to ensure your app is properly configured.
class ApiKeyValidator {
  static const String _tag = 'ApiKeyValidator';
  
  /// Validate all API keys and return a comprehensive report
  static ValidationReport validateAllKeys() {
    final report = ValidationReport();
    
    // Validate Firebase keys
    report.firebaseStatus = _validateFirebaseKeys();
    
    // Validate Map service keys
    report.mapServicesStatus = _validateMapServiceKeys();
    
    // Validate Third-party service keys
    report.thirdPartyStatus = _validateThirdPartyKeys();
    
    // Validate Security keys
    report.securityStatus = _validateSecurityKeys();
    
    // Validate Push notification keys
    report.pushNotificationStatus = _validatePushNotificationKeys();
    
    // Calculate overall status
    report.overallStatus = _calculateOverallStatus(report);
    
    // Log the report
    _logValidationReport(report);
    
    return report;
  }
  
  /// Validate Firebase configuration
  static Map<String, ValidationResult> _validateFirebaseKeys() {
    return {
      'Firebase Android API Key': _validateKey(
        ApiKeys.firebaseApiKeyAndroid,
        'AIzaSy',
        'Firebase Android API key should start with AIzaSy',
      ),
      'Firebase iOS API Key': _validateKey(
        ApiKeys.firebaseApiKeyIOS,
        'AIzaSy',
        'Firebase iOS API key should start with AIzaSy',
      ),
      'Firebase Web API Key': _validateKey(
        ApiKeys.firebaseApiKeyWeb,
        'AIzaSy',
        'Firebase Web API key should start with AIzaSy',
      ),
      'Firebase Project ID': _validateKey(
        ApiKeys.projectId,
        '',
        'Firebase Project ID is required',
        allowEmpty: false,
      ),
      'Firebase Messaging Sender ID': _validateKey(
        ApiKeys.messagingSenderId,
        '',
        'Firebase Messaging Sender ID is required',
        allowEmpty: false,
      ),
    };
  }
  
  /// Validate Map service keys
  static Map<String, ValidationResult> _validateMapServiceKeys() {
    return {};
  }
  
  /// Validate Third-party service keys
  static Map<String, ValidationResult> _validateThirdPartyKeys() {
    return {
      'OpenWeather API Key': _validateKey(
        ApiKeys.openWeatherApiKey,
        '',
        'OpenWeather API key for weather-based optimizations',
        isOptional: true,
      ),
      'Twilio Account SID': _validateKey(
        ApiKeys.twilioAccountSid,
        'AC',
        'Twilio Account SID should start with AC',
        isOptional: true,
      ),
      'Twilio Auth Token': _validateKey(
        ApiKeys.twilioAuthToken,
        '',
        'Twilio Auth Token for SMS emergency alerts',
        isOptional: true,
      ),
      'SendGrid API Key': _validateKey(
        ApiKeys.sendGridApiKey,
        'SG.',
        'SendGrid API key should start with SG.',
        isOptional: true,
      ),
    };
  }
  
  /// Validate Security keys
  static Map<String, ValidationResult> _validateSecurityKeys() {
    return {
      'JWT Secret': _validateKey(
        ApiKeys.jwtSecret,
        '',
        'JWT Secret for secure token generation',
        minLength: 32,
        isOptional: true,
      ),
      'Encryption Key': _validateKey(
        ApiKeys.encryptionKey,
        '',
        'Encryption key for sensitive data',
        minLength: 32,
        isOptional: true,
      ),
    };
  }
  
  /// Validate Push notification keys
  static Map<String, ValidationResult> _validatePushNotificationKeys() {
    return {
      'FCM Server Key': _validateKey(
        ApiKeys.fcmServerKey,
        '',
        'FCM Server Key for push notifications',
        isOptional: true,
      ),
      'APNs Key ID': _validateKey(
        ApiKeys.apnsKeyId,
        '',
        'APNs Key ID for iOS push notifications',
        isOptional: true,
      ),
      'APNs Team ID': _validateKey(
        ApiKeys.apnsTeamId,
        '',
        'APNs Team ID for iOS push notifications',
        isOptional: true,
      ),
    };
  }
  
  /// Validate a single API key
  static ValidationResult _validateKey(
    String key,
    String expectedPrefix,
    String description, {
    bool isOptional = false,
    bool allowEmpty = true,
    int minLength = 10,
  }) {
    // Check if key is placeholder
    if (key.contains('your_') || key.contains('YOUR_')) {
      return ValidationResult(
        isValid: isOptional,
        status: isOptional ? ValidationStatus.optional : ValidationStatus.missing,
        message: isOptional 
          ? 'Optional: $description'
          : 'Missing: $description',
      );
    }
    
    // Check if key is empty
    if (key.isEmpty) {
      return ValidationResult(
        isValid: allowEmpty && isOptional,
        status: allowEmpty && isOptional 
          ? ValidationStatus.optional 
          : ValidationStatus.invalid,
        message: allowEmpty && isOptional
          ? 'Optional: $description'
          : 'Empty: $description',
      );
    }
    
    // Check minimum length
    if (key.length < minLength) {
      return ValidationResult(
        isValid: false,
        status: ValidationStatus.invalid,
        message: 'Too short: $description (minimum $minLength characters)',
      );
    }
    
    // Check expected prefix
    if (expectedPrefix.isNotEmpty && !key.startsWith(expectedPrefix)) {
      return ValidationResult(
        isValid: false,
        status: ValidationStatus.invalid,
        message: 'Invalid format: $description',
      );
    }
    
    return ValidationResult(
      isValid: true,
      status: ValidationStatus.valid,
      message: 'Valid: $description',
    );
  }
  
  /// Calculate overall validation status
  static ValidationStatus _calculateOverallStatus(ValidationReport report) {
    final allResults = [
      ...report.firebaseStatus.values,
      ...report.mapServicesStatus.values,
      ...report.thirdPartyStatus.values,
      ...report.securityStatus.values,
      ...report.pushNotificationStatus.values,
    ];
    
    final invalidCount = allResults.where((r) => r.status == ValidationStatus.invalid).length;
    final missingCount = allResults.where((r) => r.status == ValidationStatus.missing).length;
    final validCount = allResults.where((r) => r.status == ValidationStatus.valid).length;
    
    if (invalidCount > 0 || missingCount > 0) {
      return ValidationStatus.invalid;
    } else if (validCount > 0) {
      return ValidationStatus.valid;
    } else {
      return ValidationStatus.optional;
    }
  }
  
  /// Log validation report
  static void _logValidationReport(ValidationReport report) {
    developer.log('[$_tag] API Key Validation Report', name: _tag);
    developer.log('[$_tag] Overall Status: ${report.overallStatus}', name: _tag);
    
    _logCategoryResults('Firebase', report.firebaseStatus);
    _logCategoryResults('Map Services', report.mapServicesStatus);
    _logCategoryResults('Third-party Services', report.thirdPartyStatus);
    _logCategoryResults('Security', report.securityStatus);
    _logCategoryResults('Push Notifications', report.pushNotificationStatus);
  }
  
  /// Log results for a category
  static void _logCategoryResults(String category, Map<String, ValidationResult> results) {
    developer.log('[$_tag] $category:', name: _tag);
    results.forEach((key, result) {
      final icon = _getStatusIcon(result.status);
      developer.log('[$_tag]   $icon $key: ${result.message}', name: _tag);
    });
  }
  
  /// Get status icon for logging
  static String _getStatusIcon(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.valid:
        return '✅';
      case ValidationStatus.invalid:
        return '❌';
      case ValidationStatus.missing:
        return '⚠️';
      case ValidationStatus.optional:
        return '🔵';
    }
  }
  
  /// Get setup instructions for missing keys
  static List<String> getSetupInstructions(ValidationReport report) {
    final instructions = <String>[];
    
    // Check for missing Firebase keys
    final missingFirebase = report.firebaseStatus.entries
        .where((e) => e.value.status == ValidationStatus.missing)
        .map((e) => e.key)
        .toList();
    
    if (missingFirebase.isNotEmpty) {
      instructions.add('🔥 Firebase Setup Required:');
      instructions.add('1. Go to https://console.firebase.google.com/');
      instructions.add('2. Select your project: ${ApiKeys.projectId}');
      instructions.add('3. Go to Project Settings > General');
      instructions.add('4. Copy the API keys for your platforms');
      instructions.add('');
    }
    
    // Google Maps setup removed (no longer used)
    
    // Check for missing Mapbox token
    if (report.mapServicesStatus['Mapbox Access Token']?.status == ValidationStatus.missing) {
      instructions.add('🗺️ Mapbox Setup (Optional):');
      instructions.add('1. Go to https://account.mapbox.com/access-tokens/');
      instructions.add('2. Create a new access token');
      instructions.add('3. Add the token to your .env file');
      instructions.add('');
    }
    
    return instructions;
  }
}

/// Validation result for a single API key
class ValidationResult {
  final bool isValid;
  final ValidationStatus status;
  final String message;
  
  const ValidationResult({
    required this.isValid,
    required this.status,
    required this.message,
  });
}

/// Overall validation report
class ValidationReport {
  Map<String, ValidationResult> firebaseStatus = {};
  Map<String, ValidationResult> mapServicesStatus = {};
  Map<String, ValidationResult> thirdPartyStatus = {};
  Map<String, ValidationResult> securityStatus = {};
  Map<String, ValidationResult> pushNotificationStatus = {};
  ValidationStatus overallStatus = ValidationStatus.invalid;
  
  /// Check if the app is ready to run
  bool get isReadyToRun {
    // App is ready if Firebase is configured and at least one map service is available
    final firebaseReady = firebaseStatus.values
        .where((r) => r.status == ValidationStatus.valid)
        .length >= 3; // At least 3 Firebase keys
    
    final mapServiceReady = mapServicesStatus.values
        .any((r) => r.status == ValidationStatus.valid);
    
    return firebaseReady && mapServiceReady;
  }
  
  /// Get critical missing keys
  List<String> get criticalMissingKeys {
    final missing = <String>[];
    
    firebaseStatus.forEach((key, result) {
      if (result.status == ValidationStatus.missing) {
        missing.add(key);
      }
    });
    
    return missing;
  }
}

/// Validation status enum
enum ValidationStatus {
  valid,
  invalid,
  missing,
  optional,
}