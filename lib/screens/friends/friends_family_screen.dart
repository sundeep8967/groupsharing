import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'package:cached_network_image/cached_network_image.dart';

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          final List friends = data?['friends'] ?? [];
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
              final friendId = friends[i];
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(friendId).snapshots(),
                builder: (context, friendSnap) {
                  if (!friendSnap.hasData) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: const Text('Loading...'),
                    );
                  }
                  final friendData = friendSnap.data!.data();
                  final name = friendData?['displayName'] ?? 'Friend';
                  final email = friendData?['email'] ?? '';
                  final photoUrl = friendData?['photoUrl'];
                  // TODO: Show online/location status if available
                  return Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl != null
                            ? CachedNetworkImageProvider(photoUrl, cacheKey: 'profile_$friendId')
                            : null,
                        child: photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline(friendData) ? Colors.green : Colors.grey,
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
          );
        },
      ),
    );
  }

  bool _isOnline(Map<String, dynamic>? friendData) {
    if (friendData == null) return false;
    final location = friendData['location'];
    if (location == null || location['updatedAt'] == null) return false;
    final updatedAt = (location['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt).inMinutes < 2;
  }
}
