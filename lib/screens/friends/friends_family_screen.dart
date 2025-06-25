import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart' as app_auth;
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/friend_service.dart'; // Adjust path if necessary
import '../../models/user_model.dart';    // Adjust path if necessary
import '../../providers/location_provider.dart'; // Adjust path if necessary
import 'package:url_launcher/url_launcher.dart';

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
  final FriendService _friendService = FriendService();
  final Map<String, Map<String, String?>> _addressCache = {};

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<app_auth.AuthProvider>(context).user;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Friends & Family',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              // Show loading state until provider is initialized
              if (!locationProvider.isInitialized) {
                return Container(
                  width: 140,
                  height: 40,
                  margin: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              
              return _buildLocationToggle(locationProvider, user);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _friendService.getFriends(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final List<UserModel> friends = snapshot.data ?? [];
          if (friends.isEmpty) {
            return Center(
              child: Text(
                'No friends yet. Add some!',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final UserModel friend = friends[i];
              return _FriendListItem(friend: friend);
            },
          );
        },
      ),
    );
  }


  Widget _buildLocationToggle(LocationProvider locationProvider, firebase_auth.User user) {
    final isOn = locationProvider.isTracking;
    
    return Container(
      width: 120,
      height: 36,
      margin: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isOn ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon and text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOn ? Icons.location_on : Icons.location_off,
                    size: 14,
                    color: isOn ? Colors.green : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOn ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Switch
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isOn,
              onChanged: (value) => _handleToggle(value, locationProvider, user),
              activeColor: Colors.green,
              activeTrackColor: Colors.green.withOpacity(0.3),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[300],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _handleToggle(bool value, LocationProvider locationProvider, firebase_auth.User user) {
    if (value) {
      locationProvider.startTracking(user.uid);
      _showSnackBar('Location sharing turned ON', Colors.green, Icons.check_circle);
    } else {
      locationProvider.stopTracking();
      _showSnackBar('Location sharing turned OFF', Colors.orange, Icons.location_off);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Separate widget for each friend item to optimize rebuilds
class _FriendListItem extends StatelessWidget {
  final UserModel friend;
  
  const _FriendListItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend.photoUrl != null
              ? CachedNetworkImageProvider(friend.photoUrl!, cacheKey: 'profile_${friend.id}')
              : null,
          child: friend.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(friend.displayName ?? 'Friend', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friend.email),
            _FriendAddressSection(friend: friend),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Online status indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isOnline(friend) ? Colors.green : Colors.grey,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
            const SizedBox(width: 8),
            // Location sharing status indicator - Only this part rebuilds
            _LocationStatusIndicator(friend: friend),
            const SizedBox(width: 4),
            // Google Maps button - Only this part rebuilds
            _GoogleMapsButton(friend: friend),
          ],
        ),
      ),
    );
  }

  bool _isOnline(UserModel friend) {
    if (friend.lastSeen == null) return false;
    // Consider a threshold, e.g., 5 minutes for "online"
    return DateTime.now().difference(friend.lastSeen!).inMinutes < 5;
  }
}

// Separate widget for location status indicator to minimize rebuilds
class _LocationStatusIndicator extends StatelessWidget {
  final UserModel friend;
  
  const _LocationStatusIndicator({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final isSharing = locationProvider.isUserSharingLocation(friend.id);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSharing 
                ? Colors.green.withOpacity(0.1) 
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSharing 
                  ? Colors.green.withOpacity(0.3) 
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSharing ? Icons.location_on : Icons.location_off,
                size: 10,
                color: isSharing ? Colors.green : Colors.grey[600],
              ),
              const SizedBox(width: 2),
              Text(
                isSharing ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: isSharing ? Colors.green : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Separate widget for Google Maps button to minimize rebuilds
class _GoogleMapsButton extends StatelessWidget {
  final UserModel friend;
  
  const _GoogleMapsButton({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final isSharing = locationProvider.isUserSharingLocation(friend.id);
        final hasLocation = locationProvider.userLocations.containsKey(friend.id);
        
        if (isSharing && hasLocation) {
          return IconButton(
            icon: _buildGoogleMapsStyleIcon(),
            onPressed: () async {
              final location = locationProvider.userLocations[friend.id];
              if (location != null) {
                final lat = location.latitude;
                final lng = location.longitude;
                final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                final androidIntent = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
                try {
                  bool launched = false;
                  launched = await launchUrl(
                    androidIntent,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) {
                    await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Google Maps.')),
                  );
                }
              }
            },
          );
        } else {
          // Show disabled map icon when location sharing is OFF
          return IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.location_off,
                color: Colors.grey[400],
                size: 20,
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${friend.displayName ?? 'Friend'} has location sharing turned off'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildGoogleMapsStyleIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4285F4), // Google Blue
            Color(0xFF1A73E8), // Darker Google Blue
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.location_on,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _FriendAddressSection extends StatefulWidget {
  final UserModel friend;
  const _FriendAddressSection({required this.friend});

  @override
  State<_FriendAddressSection> createState() => _FriendAddressSectionState();
}

class _FriendAddressSectionState extends State<_FriendAddressSection> {
  Map<String, String?>? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  void _loadAddress() async {
    final state = context.findAncestorStateOfType<_FriendsFamilyScreenState>();
    final friend = widget.friend;
    if (friend.lastLocation == null) return;
    final cache = state?._addressCache;
    final cacheKey = friend.id;
    if (cache != null && cache.containsKey(cacheKey)) {
      setState(() {
        _address = cache[cacheKey];
      });
      return;
    }
    setState(() => _loading = true);
    final addr = await Provider.of<LocationProvider>(context, listen: false)
        .getAddressForCoordinates(friend.lastLocation!.latitude, friend.lastLocation!.longitude);
    if (mounted) {
      setState(() {
        _address = addr;
        _loading = false;
      });
      if (cache != null) cache[cacheKey] = addr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    if (friend.lastLocation == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Text('No address available', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_address == null || _address!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Text('No address available', style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }
    final address = _address!['address'] ?? '';
    final city = _address!['city'] ?? '';
    final pin = _address!['postalCode'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty) Text(address, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7))),
          if (city.isNotEmpty || pin.isNotEmpty)
            Text(
              [if (pin.isNotEmpty) pin, if (city.isNotEmpty) city].join(' • '),
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
            ),
        ],
      ),
    );
  }
}
