import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        title: const Text('Friends & Family'),
        centerTitle: true,
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
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline(friend) ? Colors.green : Colors.grey,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                      IconButton(
                        icon: _buildGoogleMapsStyleIcon(),
                        onPressed: friend.lastLocation != null
                            ? () async {
                                final lat = friend.lastLocation!.latitude;
                                final lng = friend.lastLocation!.longitude;
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
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isOnline(UserModel friend) { // Changed parameter
    if (friend.lastSeen == null) return false;
    // Consider a threshold, e.g., 5 minutes for "online"
    return DateTime.now().difference(friend.lastSeen!).inMinutes < 5;
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
