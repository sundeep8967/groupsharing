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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);

      if (authProvider.user != null) {
        locationProvider.startTracking(authProvider.user!.uid);
      }
    });
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
        // Get nearby locations as a future
        final nearbyLocationsFuture = Future.wait(
          locationProvider.nearbyUsers
              .map((userId) => locationProvider.getUserLocation(userId)),
        ).then((locations) => locations.whereType<LatLng>().toList());

        return FutureBuilder<List<LatLng>>(
          future: nearbyLocationsFuture,
          builder: (context, snapshot) {
            if (locationProvider.currentLocation == null || 
                snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      locationProvider.status,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (locationProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          locationProvider.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (locationProvider.error != null)
                      ElevatedButton(
                        onPressed: () => locationProvider
                            .startTracking(authProvider.user!.uid),
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              );
            }

            // Format coordinates for display
            final currentLocation = locationProvider.currentLocation!;
            final lat = currentLocation.latitude;
            final lng = currentLocation.longitude;
            
            // Convert nearby users to markers
            final nearbyMarkers = (snapshot.data ?? []).asMap().entries.map((entry) {
              final index = entry.key;
              final location = entry.value;
              return MapMarker(
                id: 'user_$index',
                point: location,
                label: 'User ${index + 1}',
              );
            }).toSet();
            
            return Stack(
              children: [
                // App Map
                Positioned.fill(
                  child: ModernMap(
                    initialPosition: currentLocation,
                    userLocation: currentLocation,
                    markers: nearbyMarkers,
                    showUserLocation: true,
                  ),
                ),
                
                // Location Info Display
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Consumer<LocationProvider>(
                    builder: (context, locationProvider, _) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(0.9),
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
                            // Coordinates
                            Row(
                              children: [
                                const Icon(Icons.gps_fixed, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lat: $lat',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Lng: $lng',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Address
                            if (locationProvider.currentAddress != null) ...[
                              _buildInfoRow(
                                Icons.location_on,
                                locationProvider.currentAddress ?? 'Unknown address',
                              ),
                              if (locationProvider.city != null) ...[
                                const SizedBox(height: 4),
                                _buildInfoRow(
                                  Icons.location_city,
                                  locationProvider.city!,
                                  secondary: locationProvider.country ?? '',
                                ),
                              ],
                              if (locationProvider.postalCode != null) ...[
                                const SizedBox(height: 4),
                                _buildInfoRow(
                                  Icons.local_post_office,
                                  'Postal Code: ${locationProvider.postalCode!}',
                                ),
                              ],
                            ] else ...[
                              const Text(
                                'Getting address...',
                                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nearby Users: ${locationProvider.nearbyUsers.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: locationProvider.isTracking
                              ? () => locationProvider.stopTracking()
                              : () => locationProvider.startTracking(authProvider.user!.uid),
                          icon: Icon(
                            locationProvider.isTracking
                                ? Icons.location_on
                                : Icons.location_off,
                          ),
                          label: Text(
                            locationProvider.isTracking
                                ? 'Stop Sharing'
                                : 'Start Sharing',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {String? secondary}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (secondary != null && secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _buildProfileScreen() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) {
          return const Center(child: Text('Please sign in'));
        }
        
        final photoUrl = user.photoURL;
        final displayName = user.displayName ?? 'User';
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl) as ImageProvider<Object>?
                        : null,
                    child: photoUrl == null
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        color: Colors.white,
                        onPressed: () => _shareProfileLink(user.uid),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.email!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color
                        ?.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => authProvider.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        );
      },
    );
  }
}
