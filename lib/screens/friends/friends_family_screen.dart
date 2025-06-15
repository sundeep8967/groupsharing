import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/friend_service.dart'; // Adjust path if necessary
import '../../models/user_model.dart';    // Adjust path if necessary

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
  final FriendService _friendService = FriendService(); // Add this

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
                  subtitle: Text(friend.email), // UserModel.email is not nullable
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
                        icon: const Icon(Icons.location_on_outlined),
                        onPressed: () {
                          // TODO: Show friend's location on map or details
                        },
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
}
