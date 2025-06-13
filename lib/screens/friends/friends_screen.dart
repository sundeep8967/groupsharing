import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/friendship_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../chat/chat_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FriendsList(),
            _FriendRequestsList(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddFriendDialog(context);
          },
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddFriendDialog(),
    );
  }
}

class _FriendsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.uid;
    if (userId == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder(
      stream: FirebaseService.firestore
          .collection('friendships')
          .where('status', isEqualTo: FriendshipStatus.accepted.toString())
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data!.docs;
        if (friends.isEmpty) {
          return const Center(child: Text('No friends yet'));
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendship = FriendshipModel.fromMap(
              friends[index].data(),
              friends[index].id,
            );
            return FriendListTile(friendship: friendship);
          },
        );
      },
    );
  }
}

class _FriendRequestsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.uid;
    if (userId == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder(
      stream: FirebaseService.firestore
          .collection('friendships')
          .where('status', isEqualTo: FriendshipStatus.pending.toString())
          .where('friendId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No friend requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = FriendshipModel.fromMap(
              requests[index].data(),
              requests[index].id,
            );
            return FriendRequestTile(request: request);
          },
        );
      },
    );
  }
}

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key});

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _sendFriendRequest() async {
    if (_emailController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await FirebaseService.firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text)
          .get();

      if (users.docs.isEmpty) {
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
        return;
      }

      final friendId = users.docs.first.id;
      final userId = Provider.of<AuthProvider>(context, listen: false).user!.uid;

      // Check if friendship already exists
      final existingFriendships = await FirebaseService.firestore
          .collection('friendships')
          .where('userId', isEqualTo: userId)
          .where('friendId', isEqualTo: friendId)
          .get();

      if (existingFriendships.docs.isNotEmpty) {
        setState(() {
          _error = 'Friend request already sent';
          _isLoading = false;
        });
        return;
      }

      // Create new friendship request
      await FirebaseService.firestore.collection('friendships').add({
        'userId': userId,
        'friendId': friendId,
        'status': FriendshipStatus.pending.toString(),
        'createdAt': DateTime.now(),
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Friend\'s Email',
              hintText: 'Enter email address',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendFriendRequest,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }
}

class FriendListTile extends StatelessWidget {
  final FriendshipModel friendship;

  const FriendListTile({super.key, required this.friendship});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseService.firestore
          .collection('users')
          .doc(friendship.friendId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text('Loading...'),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['name'] as String? ?? 'Unknown';
        final email = userData['email'] as String? ?? '';

        return ListTile(
          leading: CircleAvatar(
            child: Text(name[0].toUpperCase()),
          ),
          title: Text(name),
          subtitle: Text(email),
          trailing: IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    friendId: friendship.friendId,
                    friendName: name,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class FriendRequestTile extends StatelessWidget {
  final FriendshipModel request;

  const FriendRequestTile({super.key, required this.request});

  Future<void> _respondToRequest(BuildContext context, bool accept) async {
    try {
      await FirebaseService.firestore
          .collection('friendships')
          .doc(request.id)
          .update({
        'status':
            accept ? FriendshipStatus.accepted : FriendshipStatus.rejected,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseService.firestore
          .collection('users')
          .doc(request.userId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text('Loading...'),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['name'] as String? ?? 'Unknown';
        final email = userData['email'] as String? ?? '';

        return ListTile(
          leading: CircleAvatar(
            child: Text(name[0].toUpperCase()),
          ),
          title: Text(name),
          subtitle: Text(email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _respondToRequest(context, true),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _respondToRequest(context, false),
              ),
            ],
          ),
        );
      },
    );
  }
}
