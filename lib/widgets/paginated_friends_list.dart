import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'loading_state_widget.dart';
import 'dart:developer' as developer;
import 'dart:async';

/// Paginated Friends List with performance optimization
class PaginatedFriendsList extends StatefulWidget {
  final String currentUserId;
  final Function(UserModel)? onFriendTap;
  final Function(UserModel)? onFriendLongPress;
  final int pageSize;
  final bool showOnlineStatus;

  const PaginatedFriendsList({
    Key? key,
    required this.currentUserId,
    this.onFriendTap,
    this.onFriendLongPress,
    this.pageSize = 20,
    this.showOnlineStatus = true,
  }) : super(key: key);

  @override
  State<PaginatedFriendsList> createState() => _PaginatedFriendsListState();
}

class _PaginatedFriendsListState extends State<PaginatedFriendsList> {
  final FriendService _friendService = FriendService();
  final ScrollController _scrollController = ScrollController();
  
  List<UserModel> _friends = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDocument;
  
  // Cache for friend status
  final Map<String, bool> _onlineStatusCache = {};
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialFriends();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Load initial friends
  Future<void> _loadInitialFriends() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      developer.log('[PaginatedFriendsList] Loading initial friends for user: ${widget.currentUserId}');
      
      final friends = await _friendService.getFriends(widget.currentUserId)
          .first
          .timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _friends = friends.take(widget.pageSize).toList();
          _hasMore = friends.length > widget.pageSize;
          _isLoading = false;
        });
        
        // Load online status in background
        _loadOnlineStatusInBackground();
      }
      
    } catch (e) {
      developer.log('[PaginatedFriendsList] Error loading friends: $e');
      if (mounted) {
        setState(() {
          _error = _getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Load more friends when scrolling
  Future<void> _loadMoreFriends() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);

    try {
      // Simulate pagination (in real app, use Firestore pagination)
      await Future.delayed(const Duration(milliseconds: 500));
      
      final allFriends = await _friendService.getFriends(widget.currentUserId)
          .first
          .timeout(const Duration(seconds: 10));
      
      final startIndex = _friends.length;
      final endIndex = (startIndex + widget.pageSize).clamp(0, allFriends.length);
      
      if (mounted && startIndex < allFriends.length) {
        setState(() {
          _friends.addAll(allFriends.sublist(startIndex, endIndex));
          _hasMore = endIndex < allFriends.length;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      developer.log('[PaginatedFriendsList] Error loading more friends: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load online status for friends in background
  void _loadOnlineStatusInBackground() {
    for (final friend in _friends) {
      _loadFriendOnlineStatus(friend.uid);
    }
  }

  /// Load individual friend's online status
  Future<void> _loadFriendOnlineStatus(String friendId) async {
    try {
      // Check if already cached
      if (_onlineStatusCache.containsKey(friendId)) return;
      
      // Load from Firestore (implement your online status logic)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        final lastSeen = data?['lastSeen'] as Timestamp?;
        final isOnline = lastSeen != null && 
            DateTime.now().difference(lastSeen.toDate()).inMinutes < 5;
        
        setState(() {
          _onlineStatusCache[friendId] = isOnline;
        });
      }
      
    } catch (e) {
      developer.log('[PaginatedFriendsList] Error loading online status for $friendId: $e');
    }
  }

  /// Handle scroll events for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFriends();
    }
  }

  /// Refresh friends list
  Future<void> _refreshFriends() async {
    setState(() {
      _friends.clear();
      _hasMore = true;
      _lastDocument = null;
      _onlineStatusCache.clear();
    });
    await _loadInitialFriends();
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorStr.contains('permission')) {
      return 'Permission denied. Please check your account settings.';
    } else if (errorStr.contains('not found')) {
      return 'Friends data not found. Please try refreshing.';
    } else {
      return 'Unable to load friends. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _friends.isEmpty) {
      return _buildErrorWidget();
    }

    if (_friends.isEmpty && _isLoading) {
      return const LoadingStateWidget(
        message: 'Loading your friends...',
        style: LoadingStyle.skeleton,
      );
    }

    if (_friends.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshFriends,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _friends.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _friends.length) {
            return _buildLoadingItem();
          }
          
          final friend = _friends[index];
          return _buildFriendItem(friend);
        },
      ),
    );
  }

  /// Build individual friend item with optimization
  Widget _buildFriendItem(UserModel friend) {
    final isOnline = _onlineStatusCache[friend.uid] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: friend.photoUrl != null 
                  ? NetworkImage(friend.photoUrl!)
                  : null,
              child: friend.photoUrl == null 
                  ? Text(friend.displayName?.substring(0, 1).toUpperCase() ?? 'U')
                  : null,
            ),
            if (widget.showOnlineStatus)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          friend.displayName ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isOnline ? 'Online' : 'Last seen recently',
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onFriendTap?.call(friend),
        onLongPress: () => widget.onFriendLongPress?.call(friend),
      ),
    );
  }

  /// Build loading item for pagination
  Widget _buildLoadingItem() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Build error widget with retry
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialFriends,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Friends Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends using their friend codes to start sharing locations!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/add-friends');
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friends'),
            ),
          ],
        ),
      ),
    );
  }
}