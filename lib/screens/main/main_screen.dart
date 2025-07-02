import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:groupsharing/widgets/smooth_modern_map.dart';
import 'package:groupsharing/models/map_marker.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/location_provider.dart';
import '../friends/friends_family_screen.dart';
import '../profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:groupsharing/services/location_service.dart';
import 'package:groupsharing/services/device_info_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

// Life360 imports
import '../../services/driving_detection_service.dart';
import '../../services/places_service.dart';
import '../../services/emergency_service.dart';
import '../../services/comprehensive_location_fix_service.dart';
import '../../services/persistent_foreground_notification_service.dart';
import '../../models/driving_session.dart';
import '../../models/smart_place.dart';
import '../../models/emergency_event.dart';
import '../../widgets/emergency_fix_button.dart';
import '../debug/native_location_test_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Set<MapMarker> _cachedMarkers = {};

  // Store last map center/zoom
  LatLng? _lastMapCenter;
  double? _lastMapZoom;
  
  // State for location info overlay
  bool _showLocationInfo = true;
  
  int _unseenNotificationCount = 0;
  
  // Add a field to track the dialog
  BuildContext? _locationDialogContext;
  
  bool _locationEnabled = true;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  
  // Life360 state variables
  bool _isDriving = false;
  DrivingSession? _currentDrivingSession;
  double _currentSpeed = 0.0;
  bool _isEmergencyActive = false;
  int _sosCountdown = 0;
  final List<SmartPlace> _userPlaces = [];
  SmartPlace? _currentPlace;
  bool _life360ServicesInitialized = false;
  
  /// Check if location sharing is working properly
  bool _isLocationSharingWorking() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    
    // Don't show fix button if user is not logged in
    if (authProvider.user == null) return true;
    
    // Location sharing is NOT working if:
    // 1. Location services are disabled
    if (!_locationEnabled) return false;
    
    // 2. User is trying to track but has errors
    if (locationProvider.error != null && locationProvider.isTracking) {
      return false;
    }
    
    // 3. User wants to share location but tracking failed to start
    if (locationProvider.error != null && !locationProvider.isTracking) {
      return false;
    }
    
    // 4. If user started tracking but still no location after reasonable time
    // (This could indicate background location issues)
    if (locationProvider.isTracking && 
        locationProvider.currentLocation == null && 
        locationProvider.status.contains('tracking')) {
      return false;
    }
    
    // 5. If status indicates problems
    if (locationProvider.status.toLowerCase().contains('error') ||
        locationProvider.status.toLowerCase().contains('failed') ||
        locationProvider.status.toLowerCase().contains('stopped')) {
      return false;
    }
    
    return true;
  }
  
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen to location service status changes
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (mounted) {
        setState(() => _locationEnabled = status == ServiceStatus.enabled);
      }
    });
    // Set initial status
    Geolocator.isLocationServiceEnabled().then((enabled) {
      if (mounted) setState(() => _locationEnabled = enabled);
    });
    
    // Sync location on app open if user is authenticated
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      LocationService().syncLocationOnAppStartOrLogin(firebaseUser.uid);
      // Start real-time device status updates (battery & ringer mode)
      DeviceInfoService.startRealtimeDeviceStatusUpdates(firebaseUser.uid);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTracking();
      _initializeLife360Services();
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.onLocationServiceDisabled = () {
        if (mounted && _locationDialogContext == null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              _locationDialogContext = dialogContext;
              return AlertDialog(
                title: const Text('Location is Off'),
                content: const Text('Location services are disabled. You now appear offline to your friends. Location sharing will resume automatically when you turn location back on.'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
      };
      
      locationProvider.onLocationServiceEnabled = () {
        if (mounted && _locationDialogContext != null) {
          Navigator.of(_locationDialogContext!).pop();
          _locationDialogContext = null;
          
          // Show a brief success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services enabled - you are now online'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      };
      
      // Listen for location service enabled
      locationProvider.addListener(() async {
        if (locationProvider.error == null && _locationDialogContext != null) {
          Navigator.of(_locationDialogContext!).pop();
          _locationDialogContext = null;
        }
      });
    });

    final appUser = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (appUser != null) {
      FirebaseFirestore.instance
        .collection('users')
        .doc(appUser.uid)
        .collection('notifications')
        .where('seen', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          setState(() {
            _unseenNotificationCount = snapshot.docs.length;
          });
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSub?.cancel();
    DeviceInfoService.stopRealtimeDeviceStatusUpdates();
    _cleanupLife360Services();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeTracking();
    }
  }

  void _initializeTracking() {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);

      final appUser = authProvider.user;
      // Only initialize the provider, don't force start tracking
      if (appUser != null && !locationProvider.isInitialized) {
        locationProvider.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing tracking: $e');
    }
  }

  /// Initialize Life360 services
  Future<void> _initializeLife360Services() async {
    if (_life360ServicesInitialized) return;
    
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      debugPrint('Initializing Life360 services for user: ${user.uid.substring(0, 8)}');

      // Initialize driving detection
      DrivingDetectionService.onDrivingStateChanged = (isDriving, session) {
        if (mounted) {
          setState(() {
            _isDriving = isDriving;
            _currentDrivingSession = session;
          });
        }
      };

      DrivingDetectionService.onSpeedChanged = (speed, accuracy) {
        if (mounted) {
          setState(() {
            _currentSpeed = speed;
          });
        }
      };

      await DrivingDetectionService.initialize(user.uid);

      // Initialize places service
      PlacesService.onPlaceEvent = (place, arrived) {
        if (mounted) {
          setState(() {
            _currentPlace = arrived ? place : null;
          });
          
          // Show notification for place events
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                arrived 
                    ? 'Arrived at ${place.name}' 
                    : 'Left ${place.name}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      };

      PlacesService.onPlaceDetected = (place) {
        if (mounted) {
          setState(() {
            _userPlaces.add(place);
          });
          
          // Show notification for new place detection
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New place detected: ${place.name}'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => _showPlaceDetails(place),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      };

      await PlacesService.initialize(user.uid);

      // Initialize emergency service
      EmergencyService.onEmergencyTriggered = (event) {
        if (mounted) {
          setState(() {
            _isEmergencyActive = true;
          });
          _showEmergencyDialog(event);
        }
      };

      EmergencyService.onSosCountdown = (countdown) {
        if (mounted) {
          setState(() {
            _sosCountdown = countdown;
          });
        }
      };

      EmergencyService.onEmergencyCancelled = () {
        if (mounted) {
          setState(() {
            _isEmergencyActive = false;
            _sosCountdown = 0;
          });
        }
      };

      await EmergencyService.initialize(user.uid);

      _life360ServicesInitialized = true;
      debugPrint('Life360 services initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Life360 services: $e');
    }
  }

  /// Cleanup Life360 services
  Future<void> _cleanupLife360Services() async {
    try {
      await DrivingDetectionService.stop();
      await PlacesService.stop();
      await EmergencyService.stop();
      _life360ServicesInitialized = false;
      debugPrint('Life360 services cleaned up');
    } catch (e) {
      debugPrint('Error cleaning up Life360 services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              const FriendsFamilyScreen(),
              _buildMapScreen(),
              _buildPlacesScreen(),
              const ProfileScreen(),
              const NotificationScreen(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NativeLocationTestScreen(),
                ),
              );
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.location_on, color: Colors.white),
            tooltip: 'Test Native Location Service',
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: [
              NavigationDestination(
                icon: Stack(
                  children: [
                    const Icon(Icons.people_outline),
                    if (_isDriving)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                selectedIcon: const Icon(Icons.people),
                label: 'Circle',
              ),
              NavigationDestination(
                icon: Stack(
                  children: [
                    const Icon(Icons.map_outlined),
                    if (_currentPlace != null)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                selectedIcon: const Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: const Icon(Icons.add_location_outlined),
                selectedIcon: const Icon(Icons.add_location),
                label: 'Places',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Stack(
                  children: [
                    Icon(
                      _isEmergencyActive ? Icons.emergency : Icons.notifications_none,
                      color: _isEmergencyActive ? Colors.red : null,
                    ),
                    if (_unseenNotificationCount > 0 && !_isEmergencyActive)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$_unseenNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                selectedIcon: Icon(
                  _isEmergencyActive ? Icons.emergency : Icons.notifications,
                  color: _isEmergencyActive ? Colors.red : null,
                ),
                label: _isEmergencyActive ? 'Emergency' : 'Alerts',
              ),
            ],
          ),
        ),
        
        // Emergency Fix Button (shows on all tabs when location sharing is not working)
        EmergencyFixButton(
          showButton: !_isLocationSharingWorking(),
        ),
        
        // Show a small notification instead of blocking the entire map
        if (!_locationEnabled && _selectedIndex == 1) // Only show on map tab
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Location services are off. Turn on to share your location.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _locationEnabled = true), // Dismiss notification
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapScreen() {
    return Consumer2<LocationProvider, app_auth.AuthProvider>(
      builder: (context, locationProvider, authProvider, _) {
        // ALWAYS show the map - get current location for map display if needed
        // Only request location once when first building the map
        if (locationProvider.currentLocation == null && !locationProvider.isInitialized) {
          // Try to get current location for map display (non-blocking)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && locationProvider.currentLocation == null) {
              locationProvider.getCurrentLocationForMap();
            }
          });
        }

        // Update markers only when nearby users change
        _updateMarkersIfNeeded(locationProvider);

        // AUTO-CENTER: Use current location as priority for initial map center
        final currentLocation = locationProvider.currentLocation;
        
        // Determine map center with priority: current location > last map center > default
        final mapCenter = currentLocation ?? 
                         _lastMapCenter ?? 
                         const LatLng(37.7749, -122.4194); // Default to San Francisco if no location
        
        // Auto-center on user location when it becomes available for the first time
        final shouldAutoCenter = currentLocation != null && _lastMapCenter == null;

        return Listener(
          onPointerUp: (_) {
            // Save map center/zoom after user interaction
            // (You may need to expose mapController from ModernMap for this)
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: SmoothModernMap(
                    key: ValueKey('smooth_modern_map_${currentLocation != null ? "with_location" : "no_location"}'),
                    initialPosition: mapCenter,
                    userLocation: currentLocation, // Always pass current location if available
                    userPhotoUrl: authProvider.user?.photoURL, // Pass user's profile picture
                    isLocationRealTime: locationProvider.isTracking, // Real-time if actively tracking
                    markers: _cachedMarkers,
                    showUserLocation: true, // Always show user location marker when location is available
                    onMarkerTap: (marker) => _showMarkerDetails(context, marker),
                    onMapMoved: (center, zoom) {
                      setState(() {
                        _lastMapCenter = center;
                        _lastMapZoom = zoom;
                      });
                    },
                  ),
                ),
              ),
              // Life360 Status Bar (Driving/Place info)
              if (_isDriving || _currentPlace != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildLife360StatusBar(),
                ),

              // Emergency SOS Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                left: 16,
                child: _buildEmergencyButton(),
              ),

              // Location Info Toggle Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 80, // Below search bar
                right: 16,
                child: Material(
                  shape: const CircleBorder(),
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _showLocationInfo = !_showLocationInfo),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        _showLocationInfo ? Icons.info : Icons.info_outline,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Location Info Overlay (only when visible and location is available)
              if (_showLocationInfo && currentLocation != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 130,
                  left: 16,
                  right: 16,
                  child: _buildLocationInfo(locationProvider),
                ),
              
              // Bottom Controls
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(locationProvider, authProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen(LocationProvider locationProvider, app_auth.AuthProvider authProvider) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              locationProvider.status,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (locationProvider.error != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  locationProvider.error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final appUser = authProvider.user;
                    if (appUser != null) {
                      locationProvider.startTracking(appUser.uid);
                    }
                },
                child: const Text('Retry'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _updateMarkersIfNeeded(LocationProvider locationProvider) {
    // Build markers from userLocations map with friend information
    final userLocations = locationProvider.userLocations;
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid;
    
    if (currentUserId == null || userLocations.isEmpty) return;
    
    final markers = <MapMarker>{};
    
    for (final entry in userLocations.entries) {
      final userId = entry.key;
      final location = entry.value;
      
      // Null safety checks
      if (userId.isEmpty || location == null) continue;
      
      // Skip current user - they're shown with the user location marker
      if (userId == currentUserId) continue;
      
      // Only show markers for users who are actively sharing location
      if (!locationProvider.isUserSharingLocation(userId)) continue;
      
      // Simple marker without async Firestore calls to prevent null exceptions
      markers.add(MapMarker(
        id: userId,
        point: location,
        label: 'Friend',
        color: Colors.blue,
      ));
    }
    
    // Only update if markers actually changed and we're still mounted
    if (mounted && (_cachedMarkers.length != markers.length || 
        !_cachedMarkers.every((m) => markers.any((newM) => newM.id == m.id && newM.point == m.point)))) {
      setState(() {
        _cachedMarkers = markers;
      });
    }
  }

  Widget _buildLocationInfo(LocationProvider locationProvider) {
    final currentLocation = locationProvider.currentLocation!;
    final lat = currentLocation.latitude.toStringAsFixed(6);
    final lng = currentLocation.longitude.toStringAsFixed(6);
    
    return AnimatedOpacity(
      opacity: _showLocationInfo ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Location Info',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _showLocationInfo = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Coordinates
              _buildInfoRow(
                Icons.gps_fixed,
                'Coordinates',
                'Lat: $lat\nLng: $lng',
              ),
              
              // Address information
              const SizedBox(height: 12),
              if (locationProvider.currentAddress != null) 
                _buildInfoRow(
                  Icons.location_on,
                  'Address',
                  locationProvider.currentAddress!,
                )
              else
                const Text(
                  'Getting address...',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              
              if (locationProvider.city != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_city,
                  'City',
                  locationProvider.city!,
                  secondary: locationProvider.country,
                ),
              ],
              
              if (locationProvider.postalCode != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.local_post_office,
                  'Postal Code',
                  locationProvider.postalCode!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String text, {String? secondary}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (secondary != null && secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(LocationProvider locationProvider, app_auth.AuthProvider authProvider) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3, // Limit height to 30% of screen
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false, // Don't add top padding since we're at the bottom
        child: SingleChildScrollView( // Make it scrollable to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Nearby users count - make it more compact
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Nearby Users: ${locationProvider.nearbyUsers.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Tracking toggle button - more compact
              SizedBox(
                height: 48, // Fixed height to prevent overflow
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final appUser = authProvider.user;
                    if (appUser == null) return;
                    
                    if (locationProvider.isTracking) {
                      locationProvider.stopTracking();
                    } else {
                      // Start tracking without automatically opening settings
                      locationProvider.startTracking(appUser.uid);
                    }
                  },
                  icon: Icon(
                    locationProvider.isTracking
                        ? Icons.location_on
                        : Icons.location_off,
                    size: 20,
                  ),
                  label: Text(
                    locationProvider.isTracking
                        ? 'Stop Sharing'
                        : 'Start Sharing',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: locationProvider.isTracking
                        ? Colors.red
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkerDetails(BuildContext context, MapMarker marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Profile picture or initials
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: marker.color ?? Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: marker.photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        marker.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildInitialsAvatar(marker);
                        },
                      ),
                    )
                  : _buildInitialsAvatar(marker),
            ),
            
            const SizedBox(height: 16),
            
            // Friend name
            Text(
              marker.label ?? 'Unknown Friend',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Online status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'Sharing Location',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Location coordinates (for debugging)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Location Coordinates',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${marker.point.latitude.toStringAsFixed(6)}\n'
                    'Lng: ${marker.point.longitude.toStringAsFixed(6)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to friend details screen
                      Navigator.pushNamed(
                        context,
                        '/friend-details',
                        arguments: {'friendId': marker.id},
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('View Friend'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(MapMarker marker) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: marker.color ?? Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          marker.label?.substring(0, 1).toUpperCase() ?? 'F',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  // _shareProfileLink function removed - was not connected to any UI elements

  /// Build Life360 status bar showing driving or place information
  Widget _buildLife360StatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isDriving ? Colors.blue.withValues(alpha: 0.9) : Colors.green.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isDriving ? Icons.directions_car : Icons.location_on,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isDriving ? 'Driving' : 'At ${_currentPlace?.name ?? 'Unknown Place'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (_isDriving && _currentSpeed > 0)
                  Text(
                    '${(_currentSpeed * 3.6).toStringAsFixed(0)} km/h',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_isDriving)
            IconButton(
              onPressed: () => _showDrivingDetails(),
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// Build emergency SOS button
  Widget _buildEmergencyButton() {
    return Material(
      shape: const CircleBorder(),
      color: _isEmergencyActive ? Colors.red : Colors.red.withValues(alpha: 0.8),
      elevation: _isEmergencyActive ? 8 : 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onLongPress: () => _triggerEmergency(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: _isEmergencyActive 
                ? Border.all(color: Colors.white, width: 3)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.emergency,
                color: Colors.white,
                size: _isEmergencyActive ? 32 : 28,
              ),
              if (_sosCountdown > 0)
                Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_sosCountdown',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show driving session details
  void _showDrivingDetails() {
    if (_currentDrivingSession == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            const Icon(Icons.directions_car, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            
            const Text(
              'Driving Session',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildDrivingInfoRow('Current Speed', '${(_currentSpeed * 3.6).toStringAsFixed(0)} km/h'),
            _buildDrivingInfoRow('Max Speed', '${((_currentDrivingSession?.maxSpeed ?? 0) * 3.6).toStringAsFixed(0)} km/h'),
            _buildDrivingInfoRow('Duration', _formatDuration(_currentDrivingSession?.duration)),
            _buildDrivingInfoRow('Distance', '${((_currentDrivingSession?.distance ?? 0) / 1000).toStringAsFixed(1)} km'),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivingInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0 min';
    final minutes = duration.inMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    }
    return '${remainingMinutes}m';
  }

  /// Show place details
  void _showPlaceDetails(SmartPlace place) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(place.typeIcon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            
            Text(
              place.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Text(
              place.typeDisplayName,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            _buildPlaceInfoRow('Visits', '${place.visitCount}'),
            _buildPlaceInfoRow('Last Visit', place.lastVisit != null 
                ? _formatDateTime(place.lastVisit!) 
                : 'Never'),
            _buildPlaceInfoRow('Notifications', place.notificationsEnabled ? 'On' : 'Off'),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to place settings screen
                      _showPlaceSettingsDialog(place);
                    },
                    child: const Text('Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Build Places screen
  Widget _buildPlacesScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: [
          IconButton(
            onPressed: () => _showAddPlaceDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _userPlaces.isEmpty
          ? _buildEmptyPlacesState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _userPlaces.length,
              itemBuilder: (context, index) {
                final place = _userPlaces[index];
                return _buildPlaceCard(place);
              },
            ),
    );
  }

  Widget _buildEmptyPlacesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Places Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add places to get notifications when you arrive or leave',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddPlaceDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Place'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(SmartPlace place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: place.isUserInside ? Colors.green : Colors.grey[300],
          child: Text(
            place.typeIcon,
            style: TextStyle(
              color: place.isUserInside ? Colors.white : Colors.grey[600],
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.typeDisplayName),
            if (place.lastVisit != null)
              Text(
                'Last visit: ${_formatDateTime(place.lastVisit!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (place.isUserInside)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Here',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              place.notificationsEnabled ? Icons.notifications : Icons.notifications_off,
              color: place.notificationsEnabled ? Colors.blue : Colors.grey,
              size: 20,
            ),
          ],
        ),
        onTap: () => _showPlaceDetails(place),
      ),
    );
  }

  void _showAddPlaceDialog() {
    final nameController = TextEditingController();
    PlaceType selectedType = PlaceType.other;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Place'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Place Name',
                  hintText: 'e.g., Home, Work, Gym',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PlaceType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Place Type',
                ),
                items: PlaceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Text(type.icon),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedType = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  await _addPlaceAtCurrentLocation(nameController.text.trim(), selectedType);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPlaceAtCurrentLocation(String name, PlaceType type) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLocation;
    
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
      return;
    }

    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      await PlacesService.createPlace(
        name: name,
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        type: type,
        radius: 100.0, // Default 100m radius
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added place: $name')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add place: $e')),
      );
    }
  }

  /// Trigger emergency SOS
  void _triggerEmergency() {
    EmergencyService.triggerSOS(
      type: EmergencyType.general,
      message: 'Manual SOS trigger from map',
    );
  }

  /// Show place settings dialog
  void _showPlaceSettingsDialog(SmartPlace place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${place.name} Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('Get notified when you arrive or leave'),
              value: place.notificationsEnabled,
              onChanged: (value) async {
                try {
                  await PlacesService.updatePlaceSettings(
                    place.id,
                    notificationsEnabled: value,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value 
                            ? 'Notifications enabled for ${place.name}'
                            : 'Notifications disabled for ${place.name}',
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update settings: $e')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Place'),
              subtitle: const Text('Remove this place permanently'),
              onTap: () => _confirmDeletePlace(place),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Confirm place deletion
  void _confirmDeletePlace(SmartPlace place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Place'),
        content: Text('Are you sure you want to delete "${place.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await PlacesService.deletePlace(place.id);
                Navigator.pop(context); // Close confirmation dialog
                Navigator.pop(context); // Close settings dialog
                setState(() {
                  _userPlaces.removeWhere((p) => p.id == place.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${place.name}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete place: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Show emergency dialog
  void _showEmergencyDialog(EmergencyEvent event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Emergency Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency type: ${event.typeDisplayName}'),
            if (event.message != null) ...[
              const SizedBox(height: 8),
              Text('Message: ${event.message}'),
            ],
            const SizedBox(height: 8),
            Text('Time: ${_formatDateTime(event.timestamp)}'),
            if (event.location != null) ...[
              const SizedBox(height: 8),
              Text('Location: ${event.location!.latitude.toStringAsFixed(6)}, ${event.location!.longitude.toStringAsFixed(6)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              EmergencyService.cancelSOS();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Emergency continues in background
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}