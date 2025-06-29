import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_event.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';

/// Life360-style emergency and SOS service
class EmergencyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  
  // State
  static String? _currentUserId;
  static bool _isEmergencyActive = false;
  static EmergencyEvent? _currentEmergency;
  static final List<EmergencyContact> _emergencyContacts = [];
  
  // SOS parameters
  static const Duration _sosCountdown = Duration(seconds: 5);
  static const Duration _emergencyTimeout = Duration(minutes: 30);
  
  // Timers
  static Timer? _sosCountdownTimer;
  static Timer? _emergencyTimeoutTimer;
  
  // Callbacks
  static Function(EmergencyEvent event)? onEmergencyTriggered;
  static Function(int countdown)? onSosCountdown;
  static Function()? onEmergencyCancelled;

  /// Initialize emergency service
  static Future<bool> initialize(String userId) async {
    try {
      _log('Initializing emergency service for user: ${userId.substring(0, 8)}');
      
      _currentUserId = userId;
      
      // Load emergency contacts
      await _loadEmergencyContacts();
      
      _log('Emergency service initialized successfully');
      return true;
    } catch (e) {
      _log('Error initializing emergency service: $e');
      return false;
    }
  }

  /// Load user's emergency contacts
  static Future<void> _loadEmergencyContacts() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('emergency_contacts')
          .orderBy('priority')
          .get();

      _emergencyContacts.clear();
      for (final doc in snapshot.docs) {
        final contact = EmergencyContact.fromMap(doc.data());
        _emergencyContacts.add(contact);
      }

      _log('Loaded ${_emergencyContacts.length} emergency contacts');
    } catch (e) {
      _log('Error loading emergency contacts: $e');
    }
  }

  /// Trigger SOS with countdown
  static Future<void> triggerSOS({
    EmergencyType type = EmergencyType.general,
    String? message,
    bool skipCountdown = false,
  }) async {
    if (_isEmergencyActive) {
      _log('Emergency already active, ignoring SOS trigger');
      return;
    }

    _log('SOS triggered with type: $type');

    if (skipCountdown) {
      await _activateEmergency(type, message);
    } else {
      await _startSosCountdown(type, message);
    }
  }

  /// Start SOS countdown
  static Future<void> _startSosCountdown(EmergencyType type, String? message) async {
    _log('Starting SOS countdown');
    
    int countdown = _sosCountdown.inSeconds;
    
    // Vibrate to alert user
    await _vibratePhone();
    
    // Show countdown notification
    if (onSosCountdown != null) {
      onSosCountdown!(countdown);
    }

    _sosCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      countdown--;
      
      if (onSosCountdown != null) {
        onSosCountdown!(countdown);
      }
      
      // Vibrate every second during countdown
      await _vibratePhone();
      
      if (countdown <= 0) {
        timer.cancel();
        await _activateEmergency(type, message);
      }
    });
  }

  /// Cancel SOS countdown
  static void cancelSOS() {
    _log('SOS cancelled by user');
    
    _sosCountdownTimer?.cancel();
    _sosCountdownTimer = null;
    
    if (onEmergencyCancelled != null) {
      onEmergencyCancelled!();
    }
  }

  /// Activate emergency
  static Future<void> _activateEmergency(EmergencyType type, String? message) async {
    if (_currentUserId == null) return;

    _log('Activating emergency: $type');
    _isEmergencyActive = true;

    // Get current location
    Position? currentLocation;
    try {
      currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _log('Error getting current location for emergency: $e');
    }

    // Create emergency event
    _currentEmergency = EmergencyEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _currentUserId!,
      type: type,
      message: message,
      location: currentLocation,
      timestamp: DateTime.now(),
      isActive: true,
    );

    // Save to Firestore
    await _saveEmergencyEvent(_currentEmergency!);

    // Update real-time database
    await _updateRealtimeEmergencyStatus(true);

    // Send notifications to emergency contacts
    await _notifyEmergencyContacts(_currentEmergency!);

    // Send notifications to family circle
    await _notifyFamilyCircle(_currentEmergency!);

    // Start emergency timeout
    _startEmergencyTimeout();

    // Notify callback
    if (onEmergencyTriggered != null) {
      onEmergencyTriggered!(_currentEmergency!);
    }

    // Show local notification
    await NotificationService.showNotification(
      title: 'Emergency Activated',
      body: 'Your emergency contacts have been notified',
      payload: 'emergency_${_currentEmergency!.id}',
    );
  }

  /// Start emergency timeout
  static void _startEmergencyTimeout() {
    _emergencyTimeoutTimer = Timer(_emergencyTimeout, () {
      _log('Emergency timeout reached, auto-resolving');
      resolveEmergency('Auto-resolved after timeout');
    });
  }

  /// Notify emergency contacts
  static Future<void> _notifyEmergencyContacts(EmergencyEvent emergency) async {
    for (final contact in _emergencyContacts) {
      await _sendEmergencyNotification(contact, emergency);
    }
  }

  /// Send emergency notification to contact
  static Future<void> _sendEmergencyNotification(
    EmergencyContact contact, 
    EmergencyEvent emergency,
  ) async {
    try {
      // Get user info
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? 'Family member';

      final locationText = emergency.location != null
          ? 'Location: https://maps.google.com/?q=${emergency.location!.latitude},${emergency.location!.longitude}'
          : 'Location: Not available';

      final message = '''
🚨 EMERGENCY ALERT 🚨

$userName has triggered an emergency alert.

Type: ${emergency.type.displayName}
Time: ${emergency.formattedTimestamp}
${emergency.message != null ? 'Message: ${emergency.message}' : ''}

$locationText

This is an automated message from the family safety app.
''';

      // Send SMS if phone number available
      if (contact.phoneNumber.isNotEmpty) {
        await _sendSMS(contact.phoneNumber, message);
      }

      // Send push notification if user ID available
      if (contact.userId != null) {
        await FCMService.sendNotificationToUser(
          contact.userId!,
          'Emergency Alert',
          '$userName has triggered an emergency alert',
          data: {
            'type': 'emergency',
            'emergencyId': emergency.id,
            'userId': emergency.userId,
            'emergencyType': emergency.type.toString(),
          },
        );
      }

      _log('Emergency notification sent to ${contact.name}');
    } catch (e) {
      _log('Error sending emergency notification to ${contact.name}: $e');
    }
  }

  /// Notify family circle members
  static Future<void> _notifyFamilyCircle(EmergencyEvent emergency) async {
    try {
      // Get family members
      final friendsSnapshot = await _firestore
          .collection('friendships')
          .where('participants', arrayContains: _currentUserId)
          .get();

      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? 'Family member';

      for (final doc in friendsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        for (final participantId in participants) {
          if (participantId != _currentUserId) {
            await FCMService.sendNotificationToUser(
              participantId,
              'Family Emergency',
              '$userName has triggered an emergency alert',
              data: {
                'type': 'family_emergency',
                'emergencyId': emergency.id,
                'userId': emergency.userId,
                'emergencyType': emergency.type.toString(),
              },
            );
          }
        }
      }
    } catch (e) {
      _log('Error notifying family circle: $e');
    }
  }

  /// Send SMS
  static Future<void> _sendSMS(String phoneNumber, String message) async {
    try {
      final uri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      _log('Error sending SMS: $e');
    }
  }

  /// Resolve emergency
  static Future<void> resolveEmergency(String resolution) async {
    if (!_isEmergencyActive || _currentEmergency == null) return;

    _log('Resolving emergency: $resolution');
    _isEmergencyActive = false;

    // Update emergency event
    _currentEmergency = _currentEmergency!.copyWith(
      isActive: false,
      resolvedAt: DateTime.now(),
      resolution: resolution,
    );

    // Save to Firestore
    await _saveEmergencyEvent(_currentEmergency!);

    // Update real-time database
    await _updateRealtimeEmergencyStatus(false);

    // Cancel timeout timer
    _emergencyTimeoutTimer?.cancel();

    // Notify contacts that emergency is resolved
    await _notifyEmergencyResolved(_currentEmergency!);

    _currentEmergency = null;
  }

  /// Notify that emergency is resolved
  static Future<void> _notifyEmergencyResolved(EmergencyEvent emergency) async {
    try {
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data();
      final userName = userData?['displayName'] ?? 'Family member';

      // Notify emergency contacts
      for (final contact in _emergencyContacts) {
        if (contact.phoneNumber.isNotEmpty) {
          final message = '''
✅ Emergency Resolved

$userName's emergency has been resolved.

Resolution: ${emergency.resolution ?? 'No details provided'}
Time: ${DateTime.now().toString().substring(0, 16)}

Thank you for your concern.
''';
          await _sendSMS(contact.phoneNumber, message);
        }

        if (contact.userId != null) {
          await FCMService.sendNotificationToUser(
            contact.userId!,
            'Emergency Resolved',
            '$userName\'s emergency has been resolved',
            data: {
              'type': 'emergency_resolved',
              'emergencyId': emergency.id,
              'userId': emergency.userId,
            },
          );
        }
      }
    } catch (e) {
      _log('Error notifying emergency resolved: $e');
    }
  }

  /// Save emergency event to Firestore
  static Future<void> _saveEmergencyEvent(EmergencyEvent event) async {
    try {
      await _firestore
          .collection('users')
          .doc(event.userId)
          .collection('emergency_events')
          .doc(event.id)
          .set(event.toMap());
    } catch (e) {
      _log('Error saving emergency event: $e');
    }
  }

  /// Update real-time emergency status
  static Future<void> _updateRealtimeEmergencyStatus(bool isActive) async {
    if (_currentUserId == null) return;

    try {
      await _realtimeDb.ref('users/$_currentUserId').update({
        'isEmergencyActive': isActive,
        'emergencyStatusUpdated': ServerValue.timestamp,
        if (isActive && _currentEmergency != null) 'currentEmergency': {
          'id': _currentEmergency!.id,
          'type': _currentEmergency!.type.toString(),
          'timestamp': _currentEmergency!.timestamp.millisecondsSinceEpoch,
        },
        if (!isActive) 'currentEmergency': null,
      });
    } catch (e) {
      _log('Error updating real-time emergency status: $e');
    }
  }

  /// Vibrate phone
  static Future<void> _vibratePhone() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      _log('Error vibrating phone: $e');
    }
  }

  /// Add emergency contact
  static Future<bool> addEmergencyContact(EmergencyContact contact) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('emergency_contacts')
          .doc(contact.id)
          .set(contact.toMap());

      _emergencyContacts.add(contact);
      _emergencyContacts.sort((a, b) => a.priority.compareTo(b.priority));

      _log('Added emergency contact: ${contact.name}');
      return true;
    } catch (e) {
      _log('Error adding emergency contact: $e');
      return false;
    }
  }

  /// Remove emergency contact
  static Future<bool> removeEmergencyContact(String contactId) async {
    if (_currentUserId == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();

      _emergencyContacts.removeWhere((c) => c.id == contactId);

      _log('Removed emergency contact: $contactId');
      return true;
    } catch (e) {
      _log('Error removing emergency contact: $e');
      return false;
    }
  }

  /// Get emergency contacts
  static List<EmergencyContact> getEmergencyContacts() {
    return List.from(_emergencyContacts);
  }

  /// Check if emergency is active
  static bool get isEmergencyActive => _isEmergencyActive;

  /// Get current emergency
  static EmergencyEvent? get currentEmergency => _currentEmergency;

  /// Stop emergency service
  static Future<void> stop() async {
    _log('Stopping emergency service');

    // Resolve any active emergency
    if (_isEmergencyActive) {
      await resolveEmergency('Service stopped');
    }

    // Cancel timers
    _sosCountdownTimer?.cancel();
    _emergencyTimeoutTimer?.cancel();

    // Clear state
    _currentUserId = null;
    _isEmergencyActive = false;
    _currentEmergency = null;
    _emergencyContacts.clear();

    _log('Emergency service stopped');
  }

  /// Cleanup service
  static Future<void> cleanup() async {
    await stop();
  }

  static void _log(String message) {
    if (kDebugMode) {
      print('EMERGENCY_SERVICE: $message');
    }
  }
}