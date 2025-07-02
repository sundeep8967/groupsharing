import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'lib/services/native_background_location_service.dart';
import 'lib/providers/location_provider.dart';

/// Comprehensive fix for background location not working for all users
/// This script diagnoses and fixes the issue where only test_user_1751448353115 works
class BackgroundLocationFix {
  
  /// Diagnose why background location isn't working for a user
  static Future<Map<String, dynamic>> diagnoseUser(String userId) async {
    final diagnosis = <String, dynamic>{
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'issues': <String>[],
      'recommendations': <String>[],
    };
    
    try {
      // Check if native service is running
      final nativeStatus = NativeBackgroundLocationService.getStatusInfo();
      diagnosis['nativeServiceStatus'] = nativeStatus;
      
      if (!nativeStatus['isRunning']) {
        diagnosis['issues'].add('Native background service not running');
        diagnosis['recommendations'].add('Restart native background service');
      }
      
      // Check if user ID matches
      if (nativeStatus['currentUserId'] != userId) {
        diagnosis['issues'].add('User ID mismatch in native service');
        diagnosis['recommendations'].add('Stop and restart service with correct user ID');
      }
      
      // Check notification info
      final notificationInfo = NativeBackgroundLocationService.getNotificationInfo();
      diagnosis['notificationInfo'] = notificationInfo;
      
      if (!notificationInfo['hasNotification']) {
        diagnosis['issues'].add('No persistent notification visible');
        diagnosis['recommendations'].add('Ensure foreground service is running');
      }
      
      return diagnosis;
    } catch (e) {
      diagnosis['error'] = e.toString();
      diagnosis['issues'].add('Failed to diagnose: $e');
      return diagnosis;
    }
  }
  
  /// Fix background location for a specific user
  static Future<bool> fixBackgroundLocationForUser(String userId) async {
    try {
      developer.log('=== FIXING BACKGROUND LOCATION FOR USER: ${userId.substring(0, 8)} ===');
      
      // Step 1: Stop all existing services
      developer.log('Step 1: Stopping all existing services...');
      await NativeBackgroundLocationService.stopService();
      await Future.delayed(const Duration(seconds: 2));
      
      // Step 2: Start native background service
      developer.log('Step 2: Starting native background service...');
      final nativeStarted = await NativeBackgroundLocationService.startService(userId);
      
      if (nativeStarted) {
        developer.log('SUCCESS: Native service started for ${userId.substring(0, 8)}');
        
        // Step 3: Verify service is running
        await Future.delayed(const Duration(seconds: 3));
        final isHealthy = await NativeBackgroundLocationService.isServiceHealthy();
        
        if (isHealthy) {
          developer.log('SUCCESS: Service is healthy and running');
          return true;
        } else {
          developer.log('WARNING: Service started but health check failed');
          return false;
        }
      } else {
        developer.log('FAILED: Could not start native service for ${userId.substring(0, 8)}');
        return false;
      }
    } catch (e) {
      developer.log('ERROR: Failed to fix background location: $e');
      return false;
    }
  }
  
  /// Fix background location for all users
  static Future<Map<String, bool>> fixBackgroundLocationForAllUsers(List<String> userIds) async {
    final results = <String, bool>{};
    
    for (final userId in userIds) {
      developer.log('Processing user: ${userId.substring(0, 8)}');
      
      // Diagnose first
      final diagnosis = await diagnoseUser(userId);
      developer.log('Diagnosis for ${userId.substring(0, 8)}: ${diagnosis['issues']}');
      
      // Apply fix
      final fixed = await fixBackgroundLocationForUser(userId);
      results[userId] = fixed;
      
      if (fixed) {
        developer.log('✅ FIXED: Background location working for ${userId.substring(0, 8)}');
      } else {
        developer.log('❌ FAILED: Could not fix background location for ${userId.substring(0, 8)}');
      }
      
      // Wait between users to avoid conflicts
      await Future.delayed(const Duration(seconds: 2));
    }
    
    return results;
  }
  
  /// Test the "Update Now" functionality for a user
  static Future<bool> testUpdateNowForUser(String userId) async {
    try {
      developer.log('=== TESTING UPDATE NOW FOR USER: ${userId.substring(0, 8)} ===');
      
      // Check if service is running
      if (!NativeBackgroundLocationService.isRunning) {
        developer.log('ERROR: Service not running, starting it first...');
        final started = await fixBackgroundLocationForUser(userId);
        if (!started) {
          developer.log('ERROR: Could not start service');
          return false;
        }
      }
      
      // Trigger update now
      developer.log('Triggering Update Now...');
      final updateTriggered = await NativeBackgroundLocationService.triggerUpdateNow();
      
      if (updateTriggered) {
        developer.log('SUCCESS: Update Now triggered successfully');
        return true;
      } else {
        developer.log('FAILED: Update Now could not be triggered');
        return false;
      }
    } catch (e) {
      developer.log('ERROR: Failed to test Update Now: $e');
      return false;
    }
  }
  
  /// Get comprehensive status for all users
  static Future<Map<String, dynamic>> getComprehensiveStatus(List<String> userIds) async {
    final status = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'totalUsers': userIds.length,
      'workingUsers': <String>[],
      'failedUsers': <String>[],
      'nativeServiceStatus': NativeBackgroundLocationService.getStatusInfo(),
      'notificationInfo': NativeBackgroundLocationService.getNotificationInfo(),
    };
    
    for (final userId in userIds) {
      final diagnosis = await diagnoseUser(userId);
      
      if (diagnosis['issues'].isEmpty) {
        status['workingUsers'].add(userId);
      } else {
        status['failedUsers'].add({
          'userId': userId,
          'issues': diagnosis['issues'],
          'recommendations': diagnosis['recommendations'],
        });
      }
    }
    
    status['workingCount'] = status['workingUsers'].length;
    status['failedCount'] = status['failedUsers'].length;
    
    return status;
  }
}

/// Widget to display background location fix UI
class BackgroundLocationFixScreen extends StatefulWidget {
  final List<String> userIds;
  
  const BackgroundLocationFixScreen({
    Key? key,
    required this.userIds,
  }) : super(key: key);
  
  @override
  State<BackgroundLocationFixScreen> createState() => _BackgroundLocationFixScreenState();
}

class _BackgroundLocationFixScreenState extends State<BackgroundLocationFixScreen> {
  Map<String, dynamic>? _status;
  bool _isFixing = false;
  
  @override
  void initState() {
    super.initState();
    _loadStatus();
  }
  
  Future<void> _loadStatus() async {
    final status = await BackgroundLocationFix.getComprehensiveStatus(widget.userIds);
    setState(() {
      _status = status;
    });
  }
  
  Future<void> _fixAllUsers() async {
    setState(() {
      _isFixing = true;
    });
    
    try {
      final results = await BackgroundLocationFix.fixBackgroundLocationForAllUsers(widget.userIds);
      
      // Show results
      final successCount = results.values.where((success) => success).length;
      final totalCount = results.length;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fixed $successCount out of $totalCount users'),
          backgroundColor: successCount == totalCount ? Colors.green : Colors.orange,
        ),
      );
      
      // Reload status
      await _loadStatus();
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Location Fix'),
        backgroundColor: Colors.blue,
      ),
      body: _status == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Summary',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text('Total Users: ${_status!['totalUsers']}'),
                          Text(
                            'Working: ${_status!['workingCount']}',
                            style: const TextStyle(color: Colors.green),
                          ),
                          Text(
                            'Failed: ${_status!['failedCount']}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Fix Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFixing ? null : _fixAllUsers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _isFixing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Fixing...'),
                              ],
                            )
                          : const Text('Fix All Users'),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Failed Users
                  if (_status!['failedUsers'].isNotEmpty) ...[
                    Text(
                      'Failed Users',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ...(_status!['failedUsers'] as List).map((user) => Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User: ${user['userId'].substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Issues: ${user['issues'].join(', ')}'),
                            const SizedBox(height: 4),
                            Text('Recommendations: ${user['recommendations'].join(', ')}'),
                          ],
                        ),
                      ),
                    )),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Working Users
                  if (_status!['workingUsers'].isNotEmpty) ...[
                    Text(
                      'Working Users',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ...(_status!['workingUsers'] as List).map((userId) => Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('User: ${userId.substring(0, 8)}'),
                          ],
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
    );
  }
}