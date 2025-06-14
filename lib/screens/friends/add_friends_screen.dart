import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest(String targetEmailOrName) async {
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    // Find user by email or name
    final query = await db.collection('users')
      .where('email', isEqualTo: targetEmailOrName)
      .get();
    final docs = query.docs;
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found.')),
      );
      return;
    }
    final targetUser = docs.first;
    final targetUserId = targetUser.id;
    if (targetUserId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot add yourself.')),
      );
      return;
    }
    // Check if request already exists
    final existing = await db.collection('friend_requests')
      .where('from', isEqualTo: user.uid)
      .where('to', isEqualTo: targetUserId)
      .where('status', isEqualTo: 'pending')
      .get();
    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request already sent.')),
      );
      return;
    }
    // Send request
    await db.collection('friend_requests').add({
      'from': user.uid,
      'to': targetUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request sent!')),
    );
  }

  Future<void> _acceptRequest(String requestId, String fromUserId) async {
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    // Update request status
    await db.collection('friend_requests').doc(requestId).update({'status': 'accepted'});
    // Add each other as friends
    await db.collection('users').doc(user.uid).update({
      'friends': FieldValue.arrayUnion([fromUserId])
    });
    await db.collection('users').doc(fromUserId).update({
      'friends': FieldValue.arrayUnion([user.uid])
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request accepted!')),
    );
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({'status': 'declined'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request declined.')),
    );
  }

  Future<void> _cancelRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request cancelled.')),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request, String requestId, {bool isReceived = true}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          child: Text(
            request['avatar'] ?? '',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          request['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${request['username'] ?? ''} • ${request['time'] ?? ''}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).hintColor,
          ),
        ),
        trailing: isReceived
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    onPressed: () => _acceptRequest(requestId, request['from']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () => _declineRequest(requestId),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request['status'] ?? '',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _cancelRequest(requestId),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 64,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final user = Provider.of<app_auth.AuthProvider>(context).user;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Friend Requests'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Received Requests
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('to', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildEmptyState('No friend requests received yet.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final requestId = docs[index].id;
                    return _buildRequestItem(data, requestId, isReceived: true);
                  },
                );
              },
            ),
            // Sent Requests
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('friend_requests')
                  .where('from', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildEmptyState('No pending friend requests.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final requestId = docs[index].id;
                    return _buildRequestItem(data, requestId, isReceived: false);
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final input = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Add Friend'),
                content: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter email to add',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _searchController.text.trim()),
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
            if (input != null && input.isNotEmpty) {
              await _sendFriendRequest(input);
              _searchController.clear();
            }
          },
          icon: const Icon(Icons.person_add),
          label: const Text('Add Friend'),
        ),
      ),
    );
  }
}
