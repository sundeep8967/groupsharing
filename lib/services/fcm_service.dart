import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for handling Firebase Cloud Messaging (FCM) for proximity notifications
/// Integrates with Firebase Cloud Functions for server-side proximity detection
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const String _wakeTopic = 'test-wake';
  
  static bool _isInitialized = false;
  static String? _currentToken;
  static Map<String, dynamic>? _pendingNavigationIntent;
  
  /// Initialize FCM service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('Initializing FCM Service...');
      
      // Initialize local notifications for foreground handling
      await _initializeLocalNotifications();
      
      // Request notification permissions
      await _requestPermissions();
      
      // Get and store FCM token
      await _setupFCMToken();
      
      // Ensure subscription to wake topic (idempotent)
      await _ensureWakeTopicSubscription();

      // Setup message handlers
      _setupMessageHandlers();
      
      _isInitialized = true;
      developer.log('FCM Service initialized successfully');
      
    } catch (e) {
      developer.log('Error initializing FCM Service: $e');
    }
  }

  /// Subscribe to the app wake topic so the server can ping the device periodically
  static Future<void> _ensureWakeTopicSubscription() async {
    try {
      await _messaging.subscribeToTopic(_wakeTopic);
      developer.log('FCM: Subscribed to topic: ' + _wakeTopic);
    } catch (e) {
      developer.log('FCM: Failed to subscribe to wake topic ($_wakeTopic): $e');
    }
  }
  
  /// Initialize local notifications for foreground message handling
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }
  
  /// Handle notification tap events
  static void _onNotificationTapped(NotificationResponse response) {
    developer.log('FCM Notification tapped: ${response.payload}');
    
    // Parse payload to determine navigation
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        // Parse the payload as a simple string or JSON
        final payload = response.payload!;
        
        // Handle different notification types
        if (payload.contains('proximity')) {
          // Extract friend ID from proximity notification
          final parts = payload.split('|');
          if (parts.length >= 2) {
            final friendId = parts[1];
            _handleProximityNavigationIntent(friendId);
          }
        } else {
          // Treat as friend ID for proximity notifications
          _handleProximityNavigationIntent(payload);
        }
      } catch (e) {
        developer.log('Error parsing FCM notification payload: $e');
      }
    }
  }
  
  /// Handle navigation intent for proximity notifications
  static void _handleProximityNavigationIntent(String friendId) {
    developer.log('Handling proximity navigation for friend: $friendId');
    
    // Store navigation intent for the app to handle when it becomes active
    _pendingNavigationIntent = {
      'type': 'proximity',
      'friendId': friendId,
      'timestamp': DateTime.now(),
    };
  }
  
  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      developer.log('FCM Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        developer.log('User granted FCM permissions');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        developer.log('User granted provisional FCM permissions');
      } else {
        developer.log('User declined or has not accepted FCM permissions');
      }
      
    } catch (e) {
      developer.log('Error requesting FCM permissions: $e');
    }
  }
  
  /// Setup FCM token management
  static Future<void> _setupFCMToken() async {
    try {
      // Get initial token
      _currentToken = await _messaging.getToken();
      if (_currentToken != null) {
        developer.log('FCM Token obtained: ${_currentToken!.substring(0, 20)}...');
        await _updateTokenOnServer(_currentToken!);
      }
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        developer.log('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _currentToken = newToken;
        _updateTokenOnServer(newToken);
      });
      
    } catch (e) {
      developer.log('Error setting up FCM token: $e');
    }
  }
  
  /// Update FCM token on server via Cloud Function
  static Future<void> _updateTokenOnServer(String token) async {
    try {
      final callable = _functions.httpsCallable('updateFcmToken');
      await callable.call({'fcmToken': token});
      developer.log('FCM token updated on server successfully');
    } catch (e) {
      developer.log('Error updating FCM token on server: $e');
    }
  }
  
  /// Setup message handlers for different app states
  static void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    
    // Handle messages when app is terminated and opened via notification
    _handleTerminatedMessage();
  }
  
  /// Handle messages when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    developer.log('Received foreground FCM message: ${message.messageId}');
    
    // Show local notification for foreground messages
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
    
    // Handle proximity notifications
    if (message.data['type'] == 'proximity') {
      _handleProximityNotification(message);
    }
  }
  
  /// Handle messages when app is in background
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    developer.log('App opened from background FCM message: ${message.messageId}');
    
    // Handle proximity notifications
    if (message.data['type'] == 'proximity') {
      _handleProximityNotification(message);
    }
  }
  
  /// Handle messages when app was terminated
  static Future<void> _handleTerminatedMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        developer.log('App opened from terminated state via FCM message: ${initialMessage.messageId}');
        
        // Handle proximity notifications
        if (initialMessage.data['type'] == 'proximity') {
          _handleProximityNotification(initialMessage);
        }
      }
    } catch (e) {
      developer.log('Error handling terminated message: $e');
    }
  }
  
  /// Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'proximity_channel',
        'Friend Proximity',
        channelDescription: 'Notifications when friends are nearby',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Friend Nearby',
        message.notification?.body ?? 'A friend is nearby',
        notificationDetails,
        payload: message.data.toString(),
      );
      
    } catch (e) {
      developer.log('Error showing local notification: $e');
    }
  }
  
  /// Handle proximity-specific notification logic
  static void _handleProximityNotification(RemoteMessage message) {
    try {
      final friendId = message.data['friendId'];
      final distance = message.data['distance'];
      
      developer.log('Proximity notification: Friend $friendId is ${distance}m away');
      
      // Store navigation intent for when user taps notification or app becomes active
      if (friendId != null) {
        _pendingNavigationIntent = {
          'type': 'proximity',
          'friendId': friendId,
          'distance': distance,
          'timestamp': DateTime.now(),
        };
        
        developer.log('Stored proximity navigation intent for friend: $friendId');
      }
      
    } catch (e) {
      developer.log('Error handling proximity notification: $e');
    }
  }
  
  /// Get current FCM token
  static String? getCurrentToken() {
    return _currentToken;
  }
  
  /// Check if FCM is initialized
  static bool isInitialized() {
    return _isInitialized;
  }
  
  /// Get proximity statistics from Cloud Function (for debugging)
  static Future<Map<String, dynamic>?> getProximityStats() async {
    try {
      final callable = _functions.httpsCallable('getProximityStats');
      final result = await callable.call();
      return result.data as Map<String, dynamic>?;
    } catch (e) {
      developer.log('Error getting proximity stats: $e');
      return null;
    }
  }
  
  /// Test proximity notification (for debugging)
  static Future<void> testProximityNotification() async {
    try {
      // Create a test notification
      const androidDetails = AndroidNotificationDetails(
        'proximity_channel',
        'Friend Proximity',
        channelDescription: 'Notifications when friends are nearby',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch,
        'Friend Nearby! (Test)',
        'Test Friend is 250m away from you',
        notificationDetails,
      );
      
      developer.log('Test proximity notification sent');
      
    } catch (e) {
      developer.log('Error sending test notification: $e');
    }
  }

  /// Send notification to a specific user
  static Future<void> sendNotificationToUser(
    String userId,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      developer.log('Sending notification to user: ${userId.substring(0, 8)}');
      
      // Call cloud function to send notification
      final callable = _functions.httpsCallable('sendNotificationToUser');
      await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
      
      developer.log('Notification sent successfully to user: ${userId.substring(0, 8)}');
    } catch (e) {
      developer.log('Error sending notification to user: $e');
    }
  }

  /// Get and clear pending navigation intent
  static Map<String, dynamic>? getPendingNavigationIntent() {
    final intent = _pendingNavigationIntent;
    _pendingNavigationIntent = null;
    return intent;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Background FCM message received: ${message.messageId}');
  
  // Handle proximity notifications in background
  if (message.data['type'] == 'proximity') {
    developer.log('Background proximity notification: ${message.notification?.body}');
  }
}