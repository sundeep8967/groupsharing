import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Data retention service for managing user data lifecycle and privacy
class DataRetentionService {
  static const String _tag = 'DataRetentionService';
  
  // Singleton instance
  static DataRetentionService? _instance;
  static DataRetentionService get instance => _instance ??= DataRetentionService._();
  
  DataRetentionService._();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Data retention policies (in days)
  static const int _locationHistoryRetentionDays = 30;
  static const int _chatHistoryRetentionDays = 90;
  static const int _activityLogRetentionDays = 60;
  static const int _deletedUserDataRetentionDays = 7;
  
  /// Initialize data retention service
  Future<void> initialize() async {
    try {
      developer.log('[$_tag] Initializing data retention service');
      
      // Schedule periodic cleanup
      _schedulePeriodicCleanup();
      
      // Check if user has consented to data retention
      await _checkUserConsent();
      
      developer.log('[$_tag] Data retention service initialized');
      
    } catch (e) {
      developer.log('[$_tag] Error initializing data retention service: $e');
    }
  }
  
  /// Schedule periodic data cleanup
  void _schedulePeriodicCleanup() {
    // Run cleanup daily
    Timer.periodic(const Duration(hours: 24), (_) {
      _performDataCleanup();
    });
    
    // Run initial cleanup after a delay
    Timer(const Duration(minutes: 5), () {
      _performDataCleanup();
    });
  }
  
  /// Perform comprehensive data cleanup
  Future<void> _performDataCleanup() async {
    try {
      developer.log('[$_tag] Starting periodic data cleanup');
      
      await Future.wait([
        _cleanupLocationHistory(),
        _cleanupChatHistory(),
        _cleanupActivityLogs(),
        _cleanupDeletedUserData(),
        _cleanupTempFiles(),
      ]);
      
      developer.log('[$_tag] Data cleanup completed');
      
    } catch (e) {
      developer.log('[$_tag] Error during data cleanup: $e');
    }
  }
  
  /// Clean up old location history
  Future<void> _cleanupLocationHistory() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: _locationHistoryRetentionDays),
      );
      
      final batch = _firestore.batch();
      
      // Query old location records
      final oldLocations = await _firestore
          .collectionGroup('locationHistory')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500) // Process in batches
          .get();
      
      for (final doc in oldLocations.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldLocations.docs.isNotEmpty) {
        await batch.commit();
        developer.log('[$_tag] Cleaned up ${oldLocations.docs.length} old location records');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error cleaning up location history: $e');
    }
  }
  
  /// Clean up old chat history
  Future<void> _cleanupChatHistory() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: _chatHistoryRetentionDays),
      );
      
      final batch = _firestore.batch();
      
      // Query old chat messages
      final oldMessages = await _firestore
          .collectionGroup('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();
      
      for (final doc in oldMessages.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldMessages.docs.isNotEmpty) {
        await batch.commit();
        developer.log('[$_tag] Cleaned up ${oldMessages.docs.length} old chat messages');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error cleaning up chat history: $e');
    }
  }
  
  /// Clean up old activity logs
  Future<void> _cleanupActivityLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: _activityLogRetentionDays),
      );
      
      final batch = _firestore.batch();
      
      // Query old activity logs
      final oldLogs = await _firestore
          .collectionGroup('activityLogs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();
      
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldLogs.docs.isNotEmpty) {
        await batch.commit();
        developer.log('[$_tag] Cleaned up ${oldLogs.docs.length} old activity logs');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error cleaning up activity logs: $e');
    }
  }
  
  /// Clean up deleted user data after grace period
  Future<void> _cleanupDeletedUserData() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: _deletedUserDataRetentionDays),
      );
      
      final batch = _firestore.batch();
      
      // Query users marked for deletion
      final deletedUsers = await _firestore
          .collection('deletedUsers')
          .where('deletedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100)
          .get();
      
      for (final doc in deletedUsers.docs) {
        final userId = doc.data()['userId'] as String;
        
        // Permanently delete all user data
        await _permanentlyDeleteUserData(userId);
        
        // Remove from deleted users collection
        batch.delete(doc.reference);
      }
      
      if (deletedUsers.docs.isNotEmpty) {
        await batch.commit();
        developer.log('[$_tag] Permanently deleted ${deletedUsers.docs.length} user accounts');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error cleaning up deleted user data: $e');
    }
  }
  
  /// Clean up temporary files and cache
  Future<void> _cleanupTempFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clean up old cached data
      final keys = prefs.getKeys().where((key) => key.startsWith('temp_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      if (keys.isNotEmpty) {
        developer.log('[$_tag] Cleaned up ${keys.length} temporary cache entries');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error cleaning up temp files: $e');
    }
  }
  
  /// Permanently delete all user data
  Future<void> _permanentlyDeleteUserData(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete user document
      batch.delete(_firestore.collection('users').doc(userId));
      
      // Delete user's location history
      final locationHistory = await _firestore
          .collection('users')
          .doc(userId)
          .collection('locationHistory')
          .get();
      
      for (final doc in locationHistory.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's friendships
      final friendships = await _firestore
          .collection('friendships')
          .where('from', isEqualTo: userId)
          .get();
      
      for (final doc in friendships.docs) {
        batch.delete(doc.reference);
      }
      
      final friendships2 = await _firestore
          .collection('friendships')
          .where('to', isEqualTo: userId)
          .get();
      
      for (final doc in friendships2.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      developer.log('[$_tag] Permanently deleted all data for user: $userId');
      
    } catch (e) {
      developer.log('[$_tag] Error permanently deleting user data: $e');
    }
  }
  
  /// Check and request user consent for data retention
  Future<void> _checkUserConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConsented = prefs.getBool('data_retention_consent') ?? false;
      
      if (!hasConsented) {
        developer.log('[$_tag] User has not consented to data retention policies');
        // In a real app, you would show a consent dialog here
      }
      
    } catch (e) {
      developer.log('[$_tag] Error checking user consent: $e');
    }
  }
  
  /// Request user consent for data retention
  Future<bool> requestUserConsent() async {
    try {
      // In a real app, show consent dialog here
      // For now, we'll assume consent is given
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_retention_consent', true);
      await prefs.setString('consent_date', DateTime.now().toIso8601String());
      
      developer.log('[$_tag] User consent recorded for data retention');
      return true;
      
    } catch (e) {
      developer.log('[$_tag] Error recording user consent: $e');
      return false;
    }
  }
  
  /// Get data retention policy information
  Map<String, dynamic> getRetentionPolicy() {
    return {
      'locationHistory': {
        'retentionDays': _locationHistoryRetentionDays,
        'description': 'Location history is kept for $_locationHistoryRetentionDays days',
      },
      'chatHistory': {
        'retentionDays': _chatHistoryRetentionDays,
        'description': 'Chat messages are kept for $_chatHistoryRetentionDays days',
      },
      'activityLogs': {
        'retentionDays': _activityLogRetentionDays,
        'description': 'Activity logs are kept for $_activityLogRetentionDays days',
      },
      'deletedUserData': {
        'retentionDays': _deletedUserDataRetentionDays,
        'description': 'Deleted user data is permanently removed after $_deletedUserDataRetentionDays days',
      },
    };
  }
  
  /// Export user data (GDPR compliance)
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      developer.log('[$_tag] Exporting data for user: $userId');
      
      final userData = <String, dynamic>{};
      
      // Export user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        userData['profile'] = userDoc.data();
      }
      
      // Export location history
      final locationHistory = await _firestore
          .collection('users')
          .doc(userId)
          .collection('locationHistory')
          .orderBy('timestamp', descending: true)
          .get();
      
      userData['locationHistory'] = locationHistory.docs
          .map((doc) => doc.data())
          .toList();
      
      // Export friendships
      final friendships = await _firestore
          .collection('friendships')
          .where('from', isEqualTo: userId)
          .get();
      
      userData['friendships'] = friendships.docs
          .map((doc) => doc.data())
          .toList();
      
      userData['exportDate'] = DateTime.now().toIso8601String();
      userData['dataRetentionPolicy'] = getRetentionPolicy();
      
      developer.log('[$_tag] Data export completed for user: $userId');
      return userData;
      
    } catch (e) {
      developer.log('[$_tag] Error exporting user data: $e');
      rethrow;
    }
  }
  
  /// Schedule user account deletion
  Future<void> scheduleUserDeletion(String userId) async {
    try {
      developer.log('[$_tag] Scheduling deletion for user: $userId');
      
      await _firestore.collection('deletedUsers').doc(userId).set({
        'userId': userId,
        'deletedAt': FieldValue.serverTimestamp(),
        'permanentDeletionDate': Timestamp.fromDate(
          DateTime.now().add(Duration(days: _deletedUserDataRetentionDays)),
        ),
      });
      
      // Mark user as deleted but keep data for grace period
      await _firestore.collection('users').doc(userId).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('[$_tag] User deletion scheduled: $userId');
      
    } catch (e) {
      developer.log('[$_tag] Error scheduling user deletion: $e');
      rethrow;
    }
  }
}