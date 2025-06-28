import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'lib/services/proximity_service.dart';
import 'lib/services/notification_service.dart';

/// Test script to verify proximity notification functionality
/// This simulates friends moving in and out of 500m range
void main() {
  runApp(const ProximityNotificationTestApp());
}

class ProximityNotificationTestApp extends StatelessWidget {
  const ProximityNotificationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximity Notification Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProximityNotificationTestScreen(),
    );
  }
}

class ProximityNotificationTestScreen extends StatefulWidget {
  const ProximityNotificationTestScreen({super.key});

  @override
  State<ProximityNotificationTestScreen> createState() => _ProximityNotificationTestScreenState();
}

class _ProximityNotificationTestScreenState extends State<ProximityNotificationTestScreen> {
  // Test locations
  final LatLng _userLocation = const LatLng(37.7749, -122.4194); // San Francisco
  
  final Map<String, LatLng> _friendLocations = {
    'friend1': const LatLng(37.7749, -122.4194), // Same location (0m)
    'friend2': const LatLng(37.7759, -122.4194), // ~100m north
    'friend3': const LatLng(37.7749, -122.4104), // ~800m east (outside range)
    'friend4': const LatLng(37.7789, -122.4194), // ~400m north
  };
  
  final Map<String, String> _friendNames = {
    'friend1': 'Alice',
    'friend2': 'Bob', 
    'friend3': 'Charlie',
    'friend4': 'Diana',
  };
  
  final Map<String, bool> _friendSharingStatus = {
    'friend1': true,
    'friend2': true,
    'friend3': true,
    'friend4': true,
  };
  
  bool _notificationsInitialized = false;
  final List<String> _testLog = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      setState(() {
        _notificationsInitialized = true;
      });
      _addToLog('✅ Notification service initialized');
    } catch (e) {
      _addToLog('❌ Failed to initialize notifications: $e');
    }
  }

  void _addToLog(String message) {
    setState(() {
      _testLog.insert(0, '${DateTime.now().toString().substring(11, 19)}: $message');
      if (_testLog.length > 20) {
        _testLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Notification Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Status and Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Proximity Notification Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Notification status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _notificationsInitialized ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _notificationsInitialized ? Colors.green[200]! : Colors.red[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _notificationsInitialized ? Icons.notifications_active : Icons.notifications_off,
                        color: _notificationsInitialized ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _notificationsInitialized ? 'Notifications Ready' : 'Notifications Not Ready',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _notificationsInitialized ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Test buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _notificationsInitialized ? _testProximityCheck : null,
                        icon: const Icon(Icons.radar),
                        label: const Text('Test Proximity'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _notificationsInitialized ? _testSingleFriend : null,
                        icon: const Icon(Icons.person),
                        label: const Text('Test Single'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _clearCooldowns,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Clear Cooldowns'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _clearLog,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Friend distances display
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Friend Distances:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._friendLocations.entries.map((entry) {
                  final friendId = entry.key;
                  final friendLocation = entry.value;
                  final friendName = _friendNames[friendId] ?? friendId;
                  final distance = ProximityService.calculateDistance(_userLocation, friendLocation);
                  final isInRange = distance <= 500;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isInRange ? Colors.green[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isInRange ? Colors.green[200]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isInRange ? Icons.circle : Icons.circle_outlined,
                          color: isInRange ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$friendName: ${ProximityService.formatDistance(distance)}',
                            style: TextStyle(
                              fontWeight: isInRange ? FontWeight.bold : FontWeight.normal,
                              color: isInRange ? Colors.green[700] : Colors.grey[700],
                            ),
                          ),
                        ),
                        if (isInRange)
                          const Text(
                            'IN RANGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          // Test log
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Log:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _testLog.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _testLog[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testProximityCheck() async {
    _addToLog('🔍 Testing proximity check for all friends...');
    
    try {
      await ProximityService.checkProximityForAllFriends(
        userLocation: _userLocation,
        friendLocations: _friendLocations,
        friendSharingStatus: _friendSharingStatus,
        currentUserId: 'test_user',
      );
      
      final friendsInProximity = ProximityService.getFriendsInProximity();
      _addToLog('✅ Proximity check completed. ${friendsInProximity.length} friends in range');
      
      for (final friendId in friendsInProximity) {
        final friendName = _friendNames[friendId] ?? friendId;
        final distance = ProximityService.calculateDistance(
          _userLocation, 
          _friendLocations[friendId]!
        );
        _addToLog('   📍 $friendName is ${ProximityService.formatDistance(distance)} away');
      }
      
    } catch (e) {
      _addToLog('❌ Error during proximity check: $e');
    }
  }

  Future<void> _testSingleFriend() async {
    const friendId = 'friend2'; // Bob at ~100m
    final friendName = _friendNames[friendId]!;
    final friendLocation = _friendLocations[friendId]!;
    
    _addToLog('👤 Testing single friend: $friendName');
    
    try {
      await ProximityService.checkProximityForFriend(
        userLocation: _userLocation,
        friendId: friendId,
        friendLocation: friendLocation,
        isFriendSharingLocation: true,
      );
      
      final distance = ProximityService.calculateDistance(_userLocation, friendLocation);
      _addToLog('✅ Single friend check completed for $friendName (${ProximityService.formatDistance(distance)})');
      
    } catch (e) {
      _addToLog('❌ Error during single friend check: $e');
    }
  }

  void _clearCooldowns() {
    NotificationService.clearCooldowns();
    ProximityService.clearProximityTracking();
    _addToLog('🔄 Cleared notification cooldowns and proximity tracking');
  }

  void _clearLog() {
    setState(() {
      _testLog.clear();
    });
  }
}