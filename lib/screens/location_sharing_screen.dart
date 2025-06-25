import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:groupsharing/widgets/modern_map.dart';
import 'package:groupsharing/providers/location_provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;
import 'package:groupsharing/services/friend_service.dart';
import 'package:groupsharing/models/user_model.dart';
import 'package:groupsharing/models/map_marker.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {

  // Create markers for friends who are sharing their location
  Set<MapMarker> _createFriendMarkers(LocationProvider locationProvider, List<UserModel> friends) {
    final markers = <MapMarker>{};
    
    for (final friend in friends) {
      // Check if friend is sharing location and has location data
      if (locationProvider.isUserSharingLocation(friend.id) && 
          locationProvider.userLocations.containsKey(friend.id)) {
        
        final location = locationProvider.userLocations[friend.id]!;
        
        markers.add(MapMarker(
          id: friend.id,
          point: location,
          label: friend.displayName ?? 'Friend',
          color: Colors.blue,
          onTap: () {
            // Show friend info when marker is tapped
            _showFriendInfo(friend, location);
          },
        ));
      }
    }
    
    return markers;
  }

  void _showFriendInfo(UserModel friend, latlong.LatLng location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: friend.photoUrl != null
                  ? CachedNetworkImageProvider(friend.photoUrl!)
                  : null,
              child: friend.photoUrl == null 
                  ? Text(friend.displayName?.substring(0, 1).toUpperCase() ?? '?')
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              friend.displayName ?? 'Friend',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // You could add navigation to Google Maps here
              },
              child: const Text('View in Maps'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, app_auth.AuthProvider>(
      builder: (context, locationProvider, authProvider, _) {
        final currentLocation = locationProvider.currentLocation;
    
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Location Sharing',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  // Show options menu
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => _buildOptionsSheet(),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Map View
              if (currentLocation != null)
                ModernMap(
                  initialPosition: currentLocation,
                  userLocation: currentLocation,
                  markers: const {},
                  showUserLocation: true,
                ),
              
              // Bottom Sheet
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // Toggle Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Text(
                              'Share your location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: locationProvider.isTracking,
                              onChanged: (value) {
                                final appUser = authProvider.user;
                                if (appUser == null) return;
                                
                                if (value) {
                                  locationProvider.startTracking(appUser.uid);
                                } else {
                                  locationProvider.stopTracking();
                                }
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                      ),
                      
                      // Friends List
                      const Divider(height: 1, thickness: 1),
                      SizedBox(
                        height: 240,
                        child: _FriendsList(
                          userLocations: locationProvider.userLocations,
                          currentLocation: currentLocation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionsSheet() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Location settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & feedback'),
            onTap: () {
              Navigator.pop(context);
              // Show help
            },
          ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  final Map<String, latlong.LatLng> userLocations;
  final latlong.LatLng? currentLocation;

  const _FriendsList({
    required this.userLocations,
    required this.currentLocation,
  });

  String _calculateDistance(latlong.LatLng from, latlong.LatLng to) {
    const distance = latlong.Distance();
    final distanceInMeters = distance.as(latlong.LengthUnit.Meter, from, to);
    
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m away';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter friends who are sharing their location
    final sharingFriends = friends.where((friend) => 
        locationProvider.isUserSharingLocation(friend.id) && 
        locationProvider.userLocations.containsKey(friend.id)
    ).toList();

    if (sharingFriends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No friends sharing location',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Ask your friends to enable location sharing',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: sharingFriends.length,
      itemBuilder: (context, index) {
        final friend = sharingFriends[index];
        final friendLocation = locationProvider.userLocations[friend.id]!;
        
        String distance = 'Unknown distance';
        if (currentLocation != null) {
          distance = _calculateDistance(currentLocation!, friendLocation);
        }

        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: friend.photoUrl != null
                ? CachedNetworkImageProvider(friend.photoUrl!)
                : null,
            backgroundColor: Theme.of(context).primaryColor,
            child: friend.photoUrl == null
                ? Text(
                    friend.displayName?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            friend.displayName ?? 'Friend',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Online • Sharing location',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
              Text(
                distance,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.location_on, color: Colors.blue),
            onPressed: () {
              // Center map on friend's location
              // You could add a callback to the parent widget to center the map
            },
          ),
        );
      },
    );
  }
}
