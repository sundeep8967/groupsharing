import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/location_provider.dart';
import '../../services/driving_detection_service.dart';
import '../../services/places_service.dart';
import '../../services/emergency_service.dart';
import '../../models/driving_session.dart';
import '../../models/smart_place.dart';
import '../../models/emergency_event.dart';
import '../friends/friends_family_screen.dart';
import '../profile/profile_screen.dart';

/// Life360-style main screen with driving detection, places, and emergency features
class Life360MainScreen extends StatefulWidget {
  const Life360MainScreen({super.key});

  @override
  State<Life360MainScreen> createState() => _Life360MainScreenState();
}

class _Life360MainScreenState extends State<Life360MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  
  // Driving detection state
  bool _isDriving = false;
  DrivingSession? _currentDrivingSession;
  double _currentSpeed = 0.0;
  
  // Emergency state
  bool _isEmergencyActive = false;
  int _sosCountdown = 0;
  
  // Places state
  List<SmartPlace> _userPlaces = [];
  SmartPlace? _currentPlace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLife360Services();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupLife360Services();
    super.dispose();
  }

  /// Initialize all Life360 services
  Future<void> _initializeLife360Services() async {
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;

    // Initialize driving detection
    DrivingDetectionService.onDrivingStateChanged = (isDriving, session) {
      setState(() {
        _isDriving = isDriving;
        _currentDrivingSession = session;
      });
    };

    DrivingDetectionService.onSpeedChanged = (speed, maxSpeed) {
      setState(() {
        _currentSpeed = speed;
      });
    };

    await DrivingDetectionService.initialize(user.uid);

    // Initialize places service
    PlacesService.onPlaceEvent = (place, arrived) {
      setState(() {
        _currentPlace = arrived ? place : null;
      });
      
      _showPlaceNotification(place, arrived);
    };

    await PlacesService.initialize(user.uid);
    _userPlaces = PlacesService.getUserPlaces();

    // Initialize emergency service
    EmergencyService.onEmergencyTriggered = (event) {
      setState(() {
        _isEmergencyActive = true;
      });
    };

    EmergencyService.onSosCountdown = (countdown) {
      setState(() {
        _sosCountdown = countdown;
      });
      
      if (countdown > 0) {
        _showSosCountdownDialog(countdown);
      }
    };

    EmergencyService.onEmergencyCancelled = () {
      setState(() {
        _sosCountdown = 0;
      });
      Navigator.of(context).pop(); // Close countdown dialog
    };

    await EmergencyService.initialize(user.uid);
  }

  /// Cleanup Life360 services
  Future<void> _cleanupLife360Services() async {
    await DrivingDetectionService.stop();
    await PlacesService.stop();
    await EmergencyService.stop();
  }

  /// Show place arrival/departure notification
  void _showPlaceNotification(SmartPlace place, bool arrived) {
    final message = arrived ? 'Arrived at ${place.name}' : 'Left ${place.name}';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(place.typeIcon),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: arrived ? Colors.green : Colors.orange,
      ),
    );
  }

  /// Show SOS countdown dialog
  void _showSosCountdownDialog(int countdown) {
    if (countdown == 5) { // Show dialog only on first countdown
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🚨 Emergency SOS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Emergency will be triggered in $countdown seconds'),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                EmergencyService.cancelSOS();
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMapScreen(),
          _buildPlacesScreen(),
          const FriendsFamilyScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// Build places screen placeholder
  Widget _buildPlacesScreen() {
    return const Center(
      child: Text('Places Screen\n(Coming Soon)'),
    );
  }

  /// Build map screen with Life360 features
  Widget _buildMapScreen() {
    return Stack(
      children: [
        // Main map
        _buildLife360Map(),
        
        // Top status bar
        _buildTopStatusBar(),
        
        // Driving status overlay
        if (_isDriving) _buildDrivingStatusOverlay(),
        
        // Emergency status overlay
        if (_isEmergencyActive) _buildEmergencyStatusOverlay(),
        
        // Current place overlay
        if (_currentPlace != null) _buildCurrentPlaceOverlay(),
      ],
    );
  }

  /// Build top status bar
  Widget _buildTopStatusBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Location sharing status
            Consumer<LocationProvider>(
              builder: (context, locationProvider, child) {
                final isSharing = locationProvider.isTracking;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSharing ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSharing ? Icons.location_on : Icons.location_off,
                        size: 16,
                        color: isSharing ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSharing ? 'Sharing' : 'Off',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSharing ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const Spacer(),
            
            // App title
            const Text(
              'Family Locator',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const Spacer(),
            
            // Emergency button
            GestureDetector(
              onTap: () => _showEmergencyOptions(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build driving status overlay
  Widget _buildDrivingStatusOverlay() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driving Detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Speed: ${(_currentSpeed * 3.6).round()} km/h',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_currentDrivingSession != null)
              Text(
                _currentDrivingSession!.formattedDuration,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build emergency status overlay
  Widget _buildEmergencyStatusOverlay() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Emergency Active',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => EmergencyService.resolveEmergency('Resolved by user'),
              child: const Text(
                'RESOLVE',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build current place overlay
  Widget _buildCurrentPlaceOverlay() {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(_currentPlace!.typeIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'At ${_currentPlace!.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build bottom navigation bar
  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.map, 'Map', 0),
          _buildNavItem(Icons.place, 'Places', 1),
          const SizedBox(width: 40), // Space for FAB
          _buildNavItem(Icons.people, 'Family', 2),
          _buildNavItem(Icons.person, 'Profile', 3),
        ],
      ),
    );
  }

  /// Build navigation item
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Build floating action button (Check-in/Emergency)
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _showQuickActions(),
      backgroundColor: Colors.red,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  /// Show quick actions menu
  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // Check-in button
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Check In'),
              subtitle: const Text('Let family know you\'re safe'),
              onTap: () {
                Navigator.pop(context);
                _checkIn();
              },
            ),
            
            // Add place button
            ListTile(
              leading: const Icon(Icons.add_location, color: Colors.blue),
              title: const Text('Add Place'),
              subtitle: const Text('Create a new place'),
              onTap: () {
                Navigator.pop(context);
                _addPlace();
              },
            ),
            
            // Emergency button
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('Emergency SOS'),
              subtitle: const Text('Alert emergency contacts'),
              onTap: () {
                Navigator.pop(context);
                _showEmergencyOptions();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show emergency options
  void _showEmergencyOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🚨 Emergency Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            
            // General emergency
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('General Emergency'),
              onTap: () {
                Navigator.pop(context);
                EmergencyService.triggerSOS();
              },
            ),
            
            // Medical emergency
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.red),
              title: const Text('Medical Emergency'),
              onTap: () {
                Navigator.pop(context);
                EmergencyService.triggerSOS(type: EmergencyType.medical);
              },
            ),
            
            // Accident
            ListTile(
              leading: const Icon(Icons.car_crash, color: Colors.red),
              title: const Text('Car Accident'),
              onTap: () {
                Navigator.pop(context);
                EmergencyService.triggerSOS(type: EmergencyType.accident);
              },
            ),
            
            // Cancel
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Check in manually
  void _checkIn() {
    // Implement check-in functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Checked in successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Add a new place
  void _addPlace() {
    // Navigate to add place screen or show dialog
    // This would open a place creation interface
  }

  /// Build Life360-style map widget
  Widget _buildLife360Map() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Text('Life360 Map\n(Driving routes, places, family members)'),
      ),
    );
  }
}