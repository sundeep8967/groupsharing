import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'lib/widgets/smooth_modern_map.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

/// Test script to verify profile picture functionality on map
/// This simulates different states: real-time vs last known location
void main() {
  runApp(const ProfilePictureMapTestApp());
}

class ProfilePictureMapTestApp extends StatelessWidget {
  const ProfilePictureMapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile Picture Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ],
        child: const ProfilePictureMapTestScreen(),
      ),
    );
  }
}

class ProfilePictureMapTestScreen extends StatefulWidget {
  const ProfilePictureMapTestScreen({super.key});

  @override
  State<ProfilePictureMapTestScreen> createState() => _ProfilePictureMapTestScreenState();
}

class _ProfilePictureMapTestScreenState extends State<ProfilePictureMapTestScreen> {
  LatLng? _simulatedUserLocation;
  String? _simulatedPhotoUrl;
  bool _isRealTime = false;

  // Test profile pictures
  final List<String> _testPhotoUrls = [
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
  ];

  final List<LatLng> _testLocations = [
    const LatLng(37.7749, -122.4194), // San Francisco
    const LatLng(40.7128, -74.0060),  // New York
    const LatLng(51.5074, -0.1278),   // London
    const LatLng(35.6762, 139.6503),  // Tokyo
  ];

  int _currentPhotoIndex = 0;
  int _currentLocationIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start with a default location and photo
    _simulatedUserLocation = _testLocations[0];
    _simulatedPhotoUrl = _testPhotoUrls[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Picture Map Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Test Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile Picture Map Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Status display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRealTime ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isRealTime ? Colors.green[200]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRealTime ? Icons.circle : Icons.access_time,
                            color: _isRealTime ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRealTime ? 'Real-time Location' : 'Last Known Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isRealTime ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRealTime 
                            ? 'Blue pulsing circle around profile picture'
                            : 'No pulsing animation, grey border',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRealTime ? Colors.green[600] : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Control buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleRealTimeStatus,
                        icon: Icon(_isRealTime ? Icons.pause : Icons.play_arrow),
                        label: Text(_isRealTime ? 'Stop Real-time' : 'Start Real-time'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRealTime ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _changeProfilePicture,
                        icon: const Icon(Icons.person),
                        label: const Text('Change Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
                        onPressed: _changeLocation,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Change Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _removeProfilePicture,
                        icon: const Icon(Icons.person_off),
                        label: const Text('Remove Photo'),
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
          
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmoothModernMap(
                  key: ValueKey('test_map_${_simulatedUserLocation?.toString()}_${_simulatedPhotoUrl}_$_isRealTime'),
                  initialPosition: _simulatedUserLocation ?? const LatLng(37.7749, -122.4194),
                  userLocation: _simulatedUserLocation,
                  userPhotoUrl: _simulatedPhotoUrl,
                  isLocationRealTime: _isRealTime,
                  markers: const {},
                  showUserLocation: true,
                  onMarkerTap: null,
                  onMapMoved: (center, zoom) {
                    debugPrint('Map moved to: ${center.latitude}, ${center.longitude} at zoom $zoom');
                  },
                ),
              ),
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Expected Behavior:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Real-time: Profile picture with blue pulsing circle and green status dot',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  '• Last known: Profile picture with grey border and orange status dot (no pulsing)',
                  style: TextStyle(fontSize: 12),
                ),
                const Text(
                  '• No photo: Default person icon with appropriate colors',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleRealTimeStatus() {
    setState(() {
      _isRealTime = !_isRealTime;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isRealTime ? '🟢 Real-time location enabled' : '🟠 Switched to last known location'),
        backgroundColor: _isRealTime ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changeProfilePicture() {
    setState(() {
      _currentPhotoIndex = (_currentPhotoIndex + 1) % _testPhotoUrls.length;
      _simulatedPhotoUrl = _testPhotoUrls[_currentPhotoIndex];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📸 Profile picture changed'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _changeLocation() {
    setState(() {
      _currentLocationIndex = (_currentLocationIndex + 1) % _testLocations.length;
      _simulatedUserLocation = _testLocations[_currentLocationIndex];
    });
    
    final locationNames = [
      'San Francisco, CA',
      'New York, NY', 
      'London, UK',
      'Tokyo, Japan'
    ];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Moved to: ${locationNames[_currentLocationIndex]}'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeProfilePicture() {
    setState(() {
      _simulatedPhotoUrl = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Profile picture removed - showing default avatar'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }
}