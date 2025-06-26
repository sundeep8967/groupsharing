import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:groupsharing/widgets/smooth_modern_map.dart';
import 'package:groupsharing/models/map_marker.dart';
import 'package:groupsharing/services/deep_link_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/location_provider.dart';
import '../friends/friends_family_screen.dart';
import '../friends/add_friends_screen.dart';
import '../profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:groupsharing/services/location_service.dart';
import 'package:groupsharing/services/device_info_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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
  double _lastMapZoom = 15.0;
  
  // State for location info overlay
  bool _showLocationInfo = true;
  
  int _unseenNotificationCount = 0;
  
  // Add a field to track the dialog
  BuildContext? _locationDialogContext;
  
  bool _locationEnabled = true;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  
  
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
              const AddFriendsScreen(),
              const ProfileScreen(),
              const NotificationScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: 'Friends',
              ),
              NavigationDestination(
                icon: const Icon(Icons.map_outlined),
                selectedIcon: const Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_add_outlined),
                selectedIcon: const Icon(Icons.person_add),
                label: 'Add',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none),
                    if (_unseenNotificationCount > 0)
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
                selectedIcon: const Icon(Icons.notifications),
                label: 'Alerts',
              ),
            ],
          ),
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

        // Use current location if available, otherwise use a default location or last known location
        final currentLocation = locationProvider.currentLocation ?? 
                               _lastMapCenter ?? 
                               const LatLng(37.7749, -122.4194); // Default to San Francisco if no location
        
        // Use last map center/zoom unless user requests recenter
        final mapCenter = _lastMapCenter ?? currentLocation;

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
                    key: const ValueKey('smooth_modern_map'),
                    initialPosition: mapCenter,
                    userLocation: locationProvider.currentLocation, // Only show user location if we have it
                    markers: _cachedMarkers,
                    showUserLocation: locationProvider.currentLocation != null, // Only show if we have user location
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
              if (_showLocationInfo && locationProvider.currentLocation != null)
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
                onPressed: () {
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
                  onPressed: () {
                    final appUser = authProvider.user;
                    if (appUser == null) return;
                    
                    if (locationProvider.isTracking) {
                      locationProvider.stopTracking();
                    } else {
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
                      // TODO: Navigate to friend details or start navigation
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
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

  Future<void> _shareProfileLink(String userId) async {
    try {
      debugPrint('=== Starting share process ===');
      debugPrint('User ID: $userId');
      
      // Generate the deep link
      debugPrint('Generating deep link...');
      final deepLink = DeepLinkService.generateProfileLink(userId);
      debugPrint('Generated deep link: $deepLink');
      
      // Create the share message
      final message = 'Add me as a friend on GroupSharing! $deepLink';
      debugPrint('Message to share: $message');
      
      // Show a snackbar to indicate sharing is starting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preparing to share...')),
        );
      }
      
      // Share the message
      debugPrint('Calling Share.share()...');
      await Share.share(
        message,
        subject: 'Add me on GroupSharing',
      );
      debugPrint('Share dialog should be visible now');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share dialog opened')),
        );
      }
      
    } catch (e, stackTrace) {
      debugPrint('=== Error in _shareProfileLink ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      debugPrint('=== Share process completed ===');
    }
  }
}