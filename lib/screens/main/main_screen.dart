import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:groupsharing/widgets/modern_map.dart';
import 'package:groupsharing/models/map_marker.dart';
import 'package:groupsharing/services/deep_link_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../friends/friends_family_screen.dart';
import '../friends/add_friends_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  
  // Cache for map markers to prevent constant rebuilding
  Set<MapMarker> _cachedMarkers = {};
  List<String> _lastNearbyUsers = [];
  
  // State for location info overlay
  bool _showLocationInfo = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTracking();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);

      if (authProvider.user != null) {
        locationProvider.startTracking(authProvider.user!.uid);
      }
    } catch (e) {
      debugPrint('Error initializing tracking: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const FriendsFamilyScreen(),
          _buildMapScreen(),
          const AddFriendsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            activeIcon: Icon(Icons.person_add),
            label: 'Add Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildMapScreen() {
    return Consumer2<LocationProvider, AuthProvider>(
      builder: (context, locationProvider, authProvider, _) {
        // Handle loading state
        if (locationProvider.currentLocation == null) {
          return _buildLoadingScreen(locationProvider, authProvider);
        }

        // Update markers only when nearby users change
        _updateMarkersIfNeeded(locationProvider);

        final currentLocation = locationProvider.currentLocation!;
        
        return Stack(
          children: [
            // Map Widget
            Positioned.fill(
              child: ModernMap(
                key: ValueKey('map_${currentLocation.latitude}_${currentLocation.longitude}'),
                initialPosition: currentLocation,
                userLocation: currentLocation,
                markers: _cachedMarkers,
                showUserLocation: true,
                onMarkerTap: (marker) {
                  _showMarkerDetails(context, marker);
                },
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
            
            // Location Info Overlay (only when visible)
            if (_showLocationInfo)
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
        );
      },
    );
  }

  Widget _buildLoadingScreen(LocationProvider locationProvider, AuthProvider authProvider) {
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
                  if (authProvider.user != null) {
                    locationProvider.startTracking(authProvider.user!.uid);
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
    // Build markers from userLocations map
    final userLocations = locationProvider.userLocations;
    final newMarkers = userLocations.entries.map((entry) {
      return MapMarker(
        id: entry.key,
        point: entry.value,
        label: 'User: ${entry.key}',
      );
    }).toSet();
    if (_cachedMarkers.length != newMarkers.length || !_cachedMarkers.every((m) => newMarkers.contains(m))) {
      _cachedMarkers = newMarkers;
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
            if (locationProvider.currentAddress != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.location_on,
                'Address',
                locationProvider.currentAddress!,
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
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Getting address...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
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

  Widget _buildBottomControls(LocationProvider locationProvider, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Nearby users count
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nearby Users: ${locationProvider.nearbyUsers.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Tracking toggle button
            ElevatedButton.icon(
              onPressed: () {
                if (authProvider.user == null) return;
                
                if (locationProvider.isTracking) {
                  locationProvider.stopTracking();
                } else {
                  locationProvider.startTracking(authProvider.user!.uid);
                }
              },
              icon: Icon(
                locationProvider.isTracking
                    ? Icons.location_on
                    : Icons.location_off,
              ),
              label: Text(
                locationProvider.isTracking
                    ? 'Stop Sharing Location'
                    : 'Start Sharing Location',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: locationProvider.isTracking
                    ? Colors.red
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkerDetails(BuildContext context, MapMarker marker) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              marker.label ?? 'Unknown User',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${marker.point.latitude.toStringAsFixed(6)}\n'
              'Lng: ${marker.point.longitude.toStringAsFixed(6)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
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