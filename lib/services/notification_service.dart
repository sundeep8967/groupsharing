import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for handling local notifications, specifically proximity notifications
/// when friends are within 500 meters range
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  
  // Track notification cooldowns to prevent spam
  static final Map<String, DateTime> _lastNotificationTime = {};
  static const Duration _notificationCooldown = Duration(minutes: 10);
  
  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      developer.log('Initializing NotificationService...');
      
      // Android initialization settings
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      // Initialize the plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Request permissions for iOS
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
      
      // Request permissions for Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      
      _isInitialized = true;
      developer.log('NotificationService initialized successfully');
      
    } catch (e) {
      developer.log('Error initializing NotificationService: $e');
    }
  }
  
  /// Handle notification tap events
  static void _onNotificationTapped(NotificationResponse response) {
    developer.log('Notification tapped: ${response.payload}');
    // TODO: Navigate to friend details or map when notification is tapped
  }
  
  /// Show a proximity notification when a friend is nearby
  static Future<void> showProximityNotification({
    required String friendId,
    required String friendName,
    required double distanceInMeters,
  }) async {
    try {
      // Check if we should show notification (cooldown period)
      if (!_shouldShowNotification(friendId)) {
        developer.log('Skipping notification for $friendId due to cooldown');
        return;
      }
      
      // Format distance for display
      final String distanceText = distanceInMeters < 100 
          ? '${distanceInMeters.round()}m'
          : '${(distanceInMeters / 100).round() * 100}m';
      
      // Create notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'proximity_channel',
        'Friend Proximity',
        channelDescription: 'Notifications when friends are nearby',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3), // Blue color
        enableVibration: true,
        playSound: true,
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Show the notification
      await _notifications.show(
        friendId.hashCode, // Use friend ID hash as notification ID
        '👋 Friend Nearby!',
        '$friendName is $distanceText away from you',
        notificationDetails,
        payload: friendId,
      );
      
      // Update last notification time
      _lastNotificationTime[friendId] = DateTime.now();
      
      developer.log('Proximity notification shown for $friendName ($distanceText away)');
      
    } catch (e) {
      developer.log('Error showing proximity notification: $e');
    }
  }
  
  /// Check if we should show a notification for this friend (cooldown check)
  static bool _shouldShowNotification(String friendId) {
    final lastTime = _lastNotificationTime[friendId];
    if (lastTime == null) return true;
    
    final timeSinceLastNotification = DateTime.now().difference(lastTime);
    return timeSinceLastNotification > _notificationCooldown;
  }
  
  /// Get friend name from Firestore for notification
  static Future<String> _getFriendName(String friendId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['displayName'] ?? 'Friend';
      }
      
      return 'Friend';
    } catch (e) {
      developer.log('Error getting friend name: $e');
      return 'Friend';
    }
  }
  
  /// Show proximity notification with friend name lookup
  static Future<void> showProximityNotificationWithName({
    required String friendId,
    required double distanceInMeters,
  }) async {
    final friendName = await _getFriendName(friendId);
    await showProximityNotification(
      friendId: friendId,
      friendName: friendName,
      distanceInMeters: distanceInMeters,
    );
  }
  
  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      developer.log('All notifications cancelled');
    } catch (e) {
      developer.log('Error cancelling notifications: $e');
    }
  }
  
  /// Cancel notification for specific friend
  static Future<void> cancelNotificationForFriend(String friendId) async {
    try {
      await _notifications.cancel(friendId.hashCode);
      developer.log('Notification cancelled for friend: $friendId');
    } catch (e) {
      developer.log('Error cancelling notification for friend: $e');
    }
  }
  
  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.areNotificationsEnabled() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final settings = await iosImplementation?.getNotificationSettings();
        return settings?.authorizationStatus == AuthorizationStatus.authorized;
      }
      return false;
    } catch (e) {
      developer.log('Error checking notification permissions: $e');
      return false;
    }
  }
  
  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.requestNotificationsPermission() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ?? false;
      }
      return false;
    } catch (e) {
      developer.log('Error requesting notification permissions: $e');
      return false;
    }
  }
  
  /// Clear notification cooldowns (for testing)
  static void clearCooldowns() {
    _lastNotificationTime.clear();
    developer.log('Notification cooldowns cleared');
  }
}