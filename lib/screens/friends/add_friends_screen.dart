import 'dart:async';

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
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Timer? _debounce;

  Future<void> _searchFriends(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
      return;
    }

    // Cancel previous debounce timer
    _debounce?.cancel();

    // Set a new timer for debouncing
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      setState(() {
        _isSearching = true;
      });

      try {
        final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
        if (user == null || !mounted) return;

        final db = FirebaseFirestore.instance;
        
        // Query for name matches
        final nameQuery = await db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(10)
            .get();
            
        // Query for email matches
        final emailQuery = await db
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: query)
            .where('email', isLessThanOrEqualTo: query + '\uf8ff')
            .limit(10)
            .get();

        if (!mounted) return;

        // Combine and deduplicate results
        final allDocs = <String, dynamic>{};
        
        for (var doc in nameQuery.docs) {
          allDocs[doc.id] = doc;
        }
        
        for (var doc in emailQuery.docs) {
          allDocs[doc.id] = doc;
        }

        final results = allDocs.values
            .where((doc) => doc.id != user.uid) // Exclude current user
            .map<Map<String, dynamic>>((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                  'name': doc['name']?.toString() ?? 'No name',
                  'email': doc['email']?.toString() ?? 'No email',
                })
            .toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  Future<void> _sendFriendRequest(String targetEmailOrCode) async {
    final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    QuerySnapshot query;
    try {
      if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(targetEmailOrCode)) {
        // Search by friend code
        query = await db.collection('users')
          .where('friendCode', isEqualTo: targetEmailOrCode.toUpperCase())
          .get();
      } else {
        // Search by email (case-insensitive)
        query = await db.collection('users')
          .where('email', isEqualTo: targetEmailOrCode.toLowerCase())
          .get();
        if (query.docs.isEmpty) {
          // Try again with original case (for legacy data)
          query = await db.collection('users')
            .where('email', isEqualTo: targetEmailOrCode)
            .get();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
      return;
    }
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
    // Check if already friends
    final userDoc = await db.collection('users').doc(user.uid).get();
    final List friends = userDoc.data()?['friends'] ?? [];
    if (friends.contains(targetUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already friends!')),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or email',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchFriends('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
        onChanged: (value) {
          _searchFriends(value);
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_isSearching && _searchResults.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isEmpty)
          _buildEmptyState('No users found')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Text(
                    (user['name']?.toString().isNotEmpty ?? false) 
                        ? user['name'].toString().substring(0, 1).toUpperCase() 
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(user['name']?.toString() ?? 'No name'),
                subtitle: Text(user['email']?.toString() ?? ''),
                trailing: ElevatedButton(
                  onPressed: () => _sendFriendRequest(user['email']?.toString() ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Add'),
                ),
              );
            },
          ),
      ],
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
              Tab(text: 'Requests'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            if (_isSearching) _buildSearchResults()
            else Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Received Requests
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('to', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('status', isEqualTo: 'pending')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return _buildEmptyState('No requests');
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final request = docs[index].data() as Map<String, dynamic>;
                          return _buildRequestItem(
                            {
                              'from': docs[index]['from'],
                              'name': request['fromName'] ?? 'Unknown User',
                              'username': request['fromEmail'] ?? '',
                              'time': request['timestamp'] != null
                                  ? '${DateTime.now().difference((request['timestamp'] as Timestamp).toDate()).inHours} hours ago'
                                  : '',
                              'avatar': request['fromName']?.substring(0, 1).toUpperCase() ?? '?',
                            },
                            docs[index].id,
                          );
                        },
                      );
                    },
                  ),
                  // Sent requests tab
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('from', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return _buildEmptyState('No sent requests');
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final request = docs[index].data() as Map<String, dynamic>;
                          return _buildRequestItem(
                            {
                              'from': docs[index]['to'],
                              'name': request['toName'] ?? 'Unknown User',
                              'username': request['toEmail'] ?? '',
                              'time': request['timestamp'] != null
                                  ? '${DateTime.now().difference((request['timestamp'] as Timestamp).toDate()).inHours} hours ago'
                                  : '',
                              'avatar': request['toName']?.substring(0, 1).toUpperCase() ?? '?',
                              'status': request['status'] ?? 'pending',
                            },
                            docs[index].id,
                            isReceived: false,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
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
