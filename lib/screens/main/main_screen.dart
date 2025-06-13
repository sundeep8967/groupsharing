import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/widgets/app_map_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';


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
          _buildMapScreen(),
          const Placeholder(child: Center(child: Text('Friends Screen'))), // Temporary placeholder
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
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
                position: location,
                title: 'User ${index + 1}',
                snippet: 'Nearby user'
              );
            }).toSet();
            
            return Stack(
              children: [
                // App Map
                Positioned.fill(
                  child: AppMapWidget(
                    initialPosition: currentLocation,
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

  Widget _buildProfileScreen() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              Text(
                authProvider.user?.displayName ?? 'User',
                style: const TextStyle(fontSize: 24),
              ),
              Text(
                authProvider.user?.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color
                      ?.withOpacity(0.7),
                ),
              ),
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
