import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:groupsharing/widgets/modern_map.dart';
import 'package:groupsharing/providers/location_provider.dart';

class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  bool _isSharingLocation = true;

  // Mock data - replace with your actual data source
  final List<Map<String, dynamic>> _friends = [
    {
      'id': '1',
      'name': 'Sarah Johnson',
      'status': 'Online',
      'timeAgo': '2 min ago',
      'distance': '1.2 km away',
      'imageUrl': 'https://randomuser.me/api/portraits/women/44.jpg',
    },
    {
      'id': '2',
      'name': 'Mike Chen',
      'status': 'Online',
      'timeAgo': '5 min ago',
      'distance': '3.5 km away',
      'imageUrl': 'https://randomuser.me/api/portraits/men/32.jpg',
    },
    {
      'id': '3',
      'name': 'Alex Taylor',
      'status': 'Offline',
      'timeAgo': '1 hour ago',
      'distance': '8.7 km away',
      'imageUrl': 'https://randomuser.me/api/portraits/men/75.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
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
                          value: _isSharingLocation,
                          onChanged: (value) {
                            setState(() {
                              _isSharingLocation = value;
                            });
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
                    child: _FriendsList(friends: _friends),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  final List<Map<String, dynamic>> friends;

  const _FriendsList({required this.friends});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: CachedNetworkImageProvider(friend['imageUrl']),
          ),
          title: Text(
            friend['name'],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${friend['status']} • ${friend['timeAgo']}',
                style: TextStyle(
                  color: friend['status'] == 'Online' 
                      ? Colors.green 
                      : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                friend['distance'],
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.location_on, color: Colors.blue),
            onPressed: () {
              // Show friend's location on map
            },
          ),
        );
      },
    );
  }
}
