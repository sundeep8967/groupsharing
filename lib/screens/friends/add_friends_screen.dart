import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/friend_service.dart'; // Adjust path if necessary
import '../../models/user_model.dart'; // Needed for targetUser type
import '../../models/friendship_model.dart'; // For FriendshipModel

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
  
  final FriendService _friendService = FriendService(); // Add this line

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
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10)
            .get();
            
        // Query for email matches
        final emailQuery = await db
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: query)
            .where('email', isLessThanOrEqualTo: '$query\uf8ff')
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
    final currentUser = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send requests.')),
      );
      return;
    }

    setState(() {
      // Potentially set a loading state if you have one
    });

    UserModel? targetUser;
    try {
      // Basic check for typical friend code pattern (e.g., 6 alphanumeric chars)
      // This regex might need adjustment based on actual friend code format.
      // The one used in the original code was: RegExp(r'^[A-Z0-9]{6}$')
      if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(targetEmailOrCode.toUpperCase())) {
        debugPrint('[UI] Searching by friend code: $targetEmailOrCode');
        targetUser = await _friendService.findUserByFriendCode(targetEmailOrCode.toUpperCase());
      } else if (targetEmailOrCode.contains('@')) { // Simple check for email
        debugPrint('[UI] Searching by email: $targetEmailOrCode');
        targetUser = await _friendService.findUserByEmail(targetEmailOrCode);
      } else {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid input. Please enter a valid email or friend code.')),
        );
        return;
      }

      if (targetUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found.')),
          );
        }
        return;
      }

      // Optional: Client-side check for adding self, though service also checks
      if (targetUser.id == currentUser.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot add yourself.')),
          );
        }
        return;
      }

      // The 'friends' check can be removed if the service handles 'already accepted' states.
      // For now, FriendService.sendFriendRequest checks for any existing record in 'friendships'.
      // If you have a separate 'friends' list on the user document for quick access, that check might still be relevant here
      // or ideally, FriendService should be aware of it.
      // For now, let's rely on FriendService's check.

      await _friendService.sendFriendRequest(currentUser.uid, targetUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }

    } catch (e) {
      // Catch exceptions from FriendService (e.g., "already exists", "failed to send")
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        // Potentially clear loading state
      });
    }
  }

  // Refactored _acceptRequest
  Future<void> _acceptRequest(String requestId) async {
    try {
      await _friendService.acceptFriendRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: ${e.toString()}')),
      );
    }
    // Reload/refresh logic might be needed if the list doesn't auto-update
  }

  // Refactored _declineRequest
  Future<void> _declineRequest(String requestId) async {
    try {
      await _friendService.rejectFriendRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining request: ${e.toString()}')),
      );
    }
    // Reload/refresh logic
  }

  // Refactored _cancelRequest
  Future<void> _cancelRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      return;
    }
    try {
      await _friendService.cancelSentRequest(requestId, currentUser.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request cancelled.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling request: ${e.toString()}')),
      );
    }
    // Optional: Refresh logic if needed
  }

  Widget _buildRequestItem(FriendshipModel friendship, {bool isReceived = true}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<UserModel?>(
        // Corrected: Use friendship.from for sender (isReceived=true), friendship.to for receiver (isReceived=false)
        future: _friendService.getUserDetails(isReceived ? friendship.from : friendship.to),
        builder: (context, userSnapshot) {
          String displayName = 'Loading...';
          String displayInitials = '?';
          String displayEmail = 'Loading...';

          if (userSnapshot.connectionState == ConnectionState.done) {
            if (userSnapshot.hasData) {
              final UserModel? user = userSnapshot.data;
              displayName = user?.displayName ?? 'Unknown User';
              displayInitials = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';
              displayEmail = user?.email ?? 'No email';
            } else {
              displayName = 'Unknown User';
              displayInitials = '?';
              displayEmail = 'N/A';
            }
          } else if (userSnapshot.hasError) {
            displayName = 'Error';
            displayInitials = '!';
            displayEmail = 'Error loading data';
          } else {
            // Loading state
            displayName = 'Loading...';
            displayInitials = '?';
            displayEmail = 'Loading...';
          }

          // Calculate time ago - assuming friendship.createdAt is a Timestamp
          String timeAgo = '';
          final duration = DateTime.now().difference(friendship.timestamp);
          if (duration.inDays > 0) {
            timeAgo = '${duration.inDays}d ago';
          } else if (duration.inHours > 0) {
            timeAgo = '${duration.inHours}h ago';
          } else if (duration.inMinutes > 0) {
            timeAgo = '${duration.inMinutes}m ago';
          } else {
            timeAgo = 'Just now';
          }


          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              child: Text(
                displayInitials,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$displayEmail • $timeAgo', // Example: using email and time ago
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
                        onPressed: () => _acceptRequest(friendship.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        onPressed: () => _declineRequest(friendship.id),
                      ),
                    ],
                  )
                : Row( // For sent requests
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friendship.status.toString().split('.').last, // Display status like "pending"
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _cancelRequest(friendship.id), // Assuming _cancelRequest uses friendship.id
                      ),
                    ],
                  ),
          );
        },
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
              color: Theme.of(context).hintColor.withValues(alpha: 0.5),
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
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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
        backgroundColor: colorScheme.surface,
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
                  StreamBuilder<List<FriendshipModel>>(
                    stream: _friendService.getPendingRequests(FirebaseAuth.instance.currentUser!.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _buildEmptyState('Error: ${snapshot.error}');
                      }
                      final requests = snapshot.data;
                      if (requests == null || requests.isEmpty) {
                        return _buildEmptyState('No pending requests');
                      }
                      return ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final friendship = requests[index];
                          // Pass the FriendshipModel directly
                          return _buildRequestItem(friendship, isReceived: true);
                        },
                      );
                    },
                  ),
                  // Sent requests tab
                  StreamBuilder<List<FriendshipModel>>( // Refactored to use List<FriendshipModel>
                    stream: _friendService.getSentRequests(FirebaseAuth.instance.currentUser!.uid), // Changed stream
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _buildEmptyState('Error: ${snapshot.error}');
                      }
                      // snapshot.data is now List<FriendshipModel>?
                      final sentRequests = snapshot.data;
                      if (sentRequests == null || sentRequests.isEmpty) {
                        return _buildEmptyState('No sent requests');
                      }
                      return ListView.builder(
                        itemCount: sentRequests.length, // Use length of the list
                        itemBuilder: (context, index) {
                          final friendship = sentRequests[index]; // Directly use the model
                          return _buildRequestItem(friendship, isReceived: false);
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
