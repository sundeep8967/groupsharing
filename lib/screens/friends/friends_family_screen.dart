import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart' as app_auth;
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../models/friend_relationship.dart';
import '../../models/friendship_model.dart';
import '../../providers/location_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'friend_details_screen.dart';
import 'add_friends_screen.dart';
import '../../services/presence_service.dart';
import 'dart:developer' as developer;

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
  final FriendService _friendService = FriendService();
  final Map<String, Map<String, String?>> _addressCache = {};
  
  // Tab controller for the three sections
  int _selectedTabIndex = 0; // 0: All, 1: Family, 2: Friends

  /// Navigates to friend details screen when a friend is tapped
  void _navigateToFriendDetails(FriendRelationship friendRelationship) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendDetailsScreen(
          friendId: friendRelationship.user.id,
          friendName: friendRelationship.user.displayName ?? 'Friend',
          friendshipId: friendRelationship.friendshipId,
          currentCategory: friendRelationship.category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<app_auth.AuthProvider>(context).user;
    if (user == null) {
      return const Center(child: Text('Please log in.'));
    }
    return Scaffold(
      body: Column(
        children: [
        // Custom App Bar
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Friends & Family',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  // Initialize the provider if not already initialized
                  if (!locationProvider.isInitialized) {
                    // Trigger initialization
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        locationProvider.initialize();
                      }
                    });
                    
                    return Container(
                      width: 120,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                          width: 1,
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
        ),
        
        // Tab selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildTabButton('All', 0, Icons.group),
              _buildTabButton('Family', 1, Icons.family_restroom),
              _buildTabButton('Friends', 2, Icons.people),
            ],
          ),
        ),
        
        // Content with proper SafeArea
        Expanded(
          child: SafeArea(
            top: false,
            child: StreamBuilder<List<FriendRelationship>>(
              stream: _friendService.getFriendsWithCategories(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final List<FriendRelationship> friendRelationships = snapshot.data ?? [];
                if (friendRelationships.isEmpty) {
                  return Center(
                    child: Text(
                      'No friends yet. Add some!',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                
                return _buildSelectedTabContent(friendRelationships);
              },
            ),
          ),
        ),
      ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddFriendsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friends'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Builds a tab button for the three sections
  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds content based on selected tab
  Widget _buildSelectedTabContent(List<FriendRelationship> friendRelationships) {
    // Group friends by category
    final familyMembers = friendRelationships
        .where((fr) => fr.category == FriendshipCategory.family)
        .toList();
    final friends = friendRelationships
        .where((fr) => fr.category == FriendshipCategory.friend)
        .toList();
    
    switch (_selectedTabIndex) {
      case 0: // All
        return _buildAllFriendsTab(friendRelationships, familyMembers, friends);
      case 1: // Family
        return _buildFamilyTab(familyMembers);
      case 2: // Friends
        return _buildFriendsTab(friends);
      default:
        return _buildAllFriendsTab(friendRelationships, familyMembers, friends);
    }
  }

  /// Builds the "All" tab content with both sections
  Widget _buildAllFriendsTab(
    List<FriendRelationship> allFriends,
    List<FriendRelationship> familyMembers,
    List<FriendRelationship> friends,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Family Section
        if (familyMembers.isNotEmpty) ...[
          _buildCategoryHeader('Family', familyMembers.length, Icons.family_restroom),
          const SizedBox(height: 8),
          ...familyMembers.map((friendRelationship) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FriendListItem(
              friendRelationship: friendRelationship,
              onTap: _navigateToFriendDetails,
            ),
          )),
          const SizedBox(height: 16),
        ],
        
        // Friends Section
        if (friends.isNotEmpty) ...[
          _buildCategoryHeader('Friends', friends.length, Icons.people),
          const SizedBox(height: 8),
          ...friends.map((friendRelationship) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FriendListItem(
              friendRelationship: friendRelationship,
              onTap: _navigateToFriendDetails,
            ),
          )),
        ],
      ],
    );
  }

  /// Builds the "Family" tab content
  Widget _buildFamilyTab(List<FriendRelationship> familyMembers) {
    if (familyMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No family members yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Friends are categorized as family by default.\nYou can change categories in friend details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('Family Members', familyMembers.length, Icons.family_restroom),
        const SizedBox(height: 16),
        ...familyMembers.map((friendRelationship) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FriendListItem(
            friendRelationship: friendRelationship,
            onTap: _navigateToFriendDetails,
          ),
        )),
      ],
    );
  }

  /// Builds the "Friends" tab content
  Widget _buildFriendsTab(List<FriendRelationship> friends) {
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No friends in this category yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can change friend categories to "Friend"\nin their details page.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader('Friends', friends.length, Icons.people),
        const SizedBox(height: 16),
        ...friends.map((friendRelationship) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FriendListItem(
            friendRelationship: friendRelationship,
            onTap: _navigateToFriendDetails,
          ),
        )),
      ],
    );
  }


  Widget _buildCategoryHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationToggle(LocationProvider locationProvider, firebase_auth.User user) {
    final isOn = locationProvider.isTracking;
    
    return Container(
      width: 120,
      height: 36,
      decoration: BoxDecoration(
        color: isOn ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with fixed size - subtle animation when toggling
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isToggling 
                  ? Icon(
                      Icons.sync,
                      key: const ValueKey('loading'),
                      size: 12,
                      color: isOn ? Colors.green : Colors.blue,
                    )
                  : Icon(
                      isOn ? Icons.location_on : Icons.location_off,
                      key: ValueKey(isOn ? 'on' : 'off'),
                      size: 12,
                      color: isOn ? Colors.green : Colors.grey[600],
                    ),
            ),
            const SizedBox(width: 4),
            // Text with flexible sizing but constrained
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _isToggling ? '...' : (isOn ? 'ON' : 'OFF'),
                  key: ValueKey(_isToggling ? 'loading' : (isOn ? 'on' : 'off')),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _isToggling 
                        ? (isOn ? Colors.green : Colors.blue)
                        : (isOn ? Colors.green : Colors.grey[600]),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Switch with fixed size
            SizedBox(
              width: 32,
              child: Transform.scale(
                scale: 0.6,
                child: Switch(
                  value: isOn,
                  onChanged: (value) => _handleToggle(value, locationProvider, user), // Keep interactive
                  activeColor: Colors.green,
                  activeTrackColor: Colors.green.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: Colors.grey[300],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToggling = false; // Add state to prevent multiple toggles
  
  void _handleToggle(bool value, LocationProvider locationProvider, firebase_auth.User user) async {
    developer.log('Toggle pressed: $value, current tracking: ${locationProvider.isTracking}');
    
    // Prevent multiple simultaneous toggles
    if (_isToggling) {
      developer.log('Toggle already in progress, ignoring');
      return;
    }
    
    // Prevent double-toggling
    if (value == locationProvider.isTracking) {
      developer.log('Toggle value same as current state, ignoring');
      return;
    }
    
    // Show immediate feedback with optimistic UI update
    _isToggling = true;
    if (mounted) setState(() {});
    
    // Show immediate feedback notification for better UX
    if (value) {
      _showSnackBar('Enabling location sharing...', Colors.blue, Icons.location_searching);
    } else {
      _showSnackBar('Disabling location sharing...', Colors.orange, Icons.location_off);
    }
    
    try {
      if (value) {
        developer.log('Starting location tracking for user: ${user.uid}');
        await locationProvider.startTracking(user.uid);
        
        // Quick verification with shorter delay for better UX
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (mounted) {
          _showSnackBar('Location ON', Colors.green, Icons.check_circle);
        }
      } else {
        developer.log('Stopping location tracking');
        await locationProvider.stopTracking();
        
        // Quick verification with shorter delay for better UX
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (mounted) {
          _showSnackBar('Location OFF', Colors.grey, Icons.location_off);
        }
      }
    } catch (e) {
      developer.log('Error toggling location sharing: $e');
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
      }
    } finally {
      _isToggling = false;
      if (mounted) setState(() {});
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (!mounted) return;
    
    // Determine text color based on background brightness
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final textColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final iconColor = brightness == Brightness.dark ? Colors.white : Colors.black87;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2, // Allow up to 2 lines for longer messages
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2), // Quick feedback duration
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Updated friend list item to work with FriendRelationship - Compact & Beautiful Design
class _FriendListItem extends StatelessWidget {
  final FriendRelationship friendRelationship;
  final void Function(FriendRelationship) onTap;
  
  const _FriendListItem({
    required this.friendRelationship,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final friend = friendRelationship.user;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(friendRelationship),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Profile Photo with Status Indicator
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.pink.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.pink,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: friend.photoUrl != null
                              ? CachedNetworkImageProvider(friend.photoUrl!, cacheKey: 'profile_${friend.id}')
                              : null,
                          child: friend.photoUrl == null 
                              ? const Icon(Icons.person, size: 24, color: Colors.grey) 
                              : null,
                        ),
                      ),
                    ),
                    // Online status indicator
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Consumer<LocationProvider>(
                        builder: (context, locationProvider, child) {
                          final isOnline = locationProvider.isUserSharingLocation(friend.id);
                          return Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? Colors.green : Colors.grey[400],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // Friend Info Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Category Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              friend.displayName ?? 'Friend',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: friendRelationship.category == FriendshipCategory.family 
                                  ? Colors.purple.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: friendRelationship.category == FriendshipCategory.family 
                                    ? Colors.purple.withValues(alpha: 0.3)
                                    : Colors.blue.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              friendRelationship.categoryDisplayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: friendRelationship.category == FriendshipCategory.family 
                                    ? Colors.purple[700]
                                    : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Address Section - Always show complete address
                      _CompactFriendAddressSection(friend: friend),
                      
                      const SizedBox(height: 6),
                      
                      // Status Row with enhanced offline info
                      Row(
                        children: [
                          // Location sharing status
                          _CompactLocationStatusIndicator(friend: friend),
                          const SizedBox(width: 8),
                          // Last seen with timestamp
                          Expanded(
                            child: Consumer<LocationProvider>(
                              builder: (context, locationProvider, child) {
                                final isOnline = locationProvider.isUserSharingLocation(friend.id);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getLastSeenText(friend, context),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    // Show additional timestamp for offline friends
                                    if (!isOnline && friend.lastSeen != null)
                                      Text(
                                        _getDetailedTimestamp(friend.lastSeen!),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Action Button
                _CompactGoogleMapsButton(friend: friend),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _getLastSeenText(UserModel friend, BuildContext context) {
    // Use the new presence service to format last seen text based on location sharing
    // Check LocationProvider for more recent location update data
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final userLocationData = locationProvider.userLocations[friend.id];
    
    // Use the most recent timestamp available
    int? lastLocationUpdate;
    if (userLocationData != null) {
      // Use current location timestamp if available
      lastLocationUpdate = DateTime.now().millisecondsSinceEpoch;
    } else if (friend.lastSeen != null) {
      // Fall back to friend's last seen
      lastLocationUpdate = friend.lastSeen!.millisecondsSinceEpoch;
    }
    
    final userData = {
      'locationSharingEnabled': friend.locationSharingEnabled,
      'lastLocationUpdate': lastLocationUpdate,
      'lastSeen': friend.lastSeen?.millisecondsSinceEpoch,
    };
    
    final presenceText = PresenceService.getLastSeenText(userData);
    
    // If friend is offline and we have a last seen time, show more detailed info
    if (!PresenceService.isUserOnline(userData) && friend.lastSeen != null) {
      final lastSeenTime = friend.lastSeen!;
      final now = DateTime.now();
      final difference = now.difference(lastSeenTime);
      
      if (difference.inMinutes < 60) {
        return 'Last seen ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Last seen ${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return 'Last seen ${difference.inDays}d ago';
      } else {
        return 'Last seen ${lastSeenTime.day}/${lastSeenTime.month}';
      }
    }
    
    return presenceText;
  }

  String _getDetailedTimestamp(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inDays == 0) {
      // Today - show time
      final hour = lastSeen.hour;
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today at $displayHour:$minute $period';
    } else if (difference.inDays == 1) {
      // Yesterday - show time
      final hour = lastSeen.hour;
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Yesterday at $displayHour:$minute $period';
    } else if (difference.inDays < 7) {
      // This week - show day and time
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekday = weekdays[lastSeen.weekday - 1];
      final hour = lastSeen.hour;
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$weekday at $displayHour:$minute $period';
    } else {
      // Older - show date
      final day = lastSeen.day.toString().padLeft(2, '0');
      final month = lastSeen.month.toString().padLeft(2, '0');
      final year = lastSeen.year;
      return '$day/$month/$year';
    }
  }
}

// Compact location status indicator
class _CompactLocationStatusIndicator extends StatelessWidget {
  final UserModel friend;
  
  const _CompactLocationStatusIndicator({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final isSharing = locationProvider.isUserSharingLocation(friend.id);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSharing 
                ? Colors.green.withValues(alpha: 0.1) 
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSharing 
                  ? Colors.green.withValues(alpha: 0.3) 
                  : Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSharing ? Icons.location_on : Icons.location_off,
                size: 8,
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

// Keep the existing location status indicator for backward compatibility
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
                ? Colors.green.withValues(alpha: 0.1) 
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSharing 
                  ? Colors.green.withValues(alpha: 0.3) 
                  : Colors.grey.withValues(alpha: 0.3),
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

// Compact Google Maps button
class _CompactGoogleMapsButton extends StatelessWidget {
  final UserModel friend;
  
  const _CompactGoogleMapsButton({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final isSharing = locationProvider.isUserSharingLocation(friend.id);
        final hasLocation = locationProvider.userLocations.containsKey(friend.id);
        
        if (isSharing && hasLocation) {
          return GestureDetector(
            onTap: () async {
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
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF1A73E8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 18,
              ),
            ),
          );
        } else {
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_off,
              color: Colors.grey[400],
              size: 18,
            ),
          );
        }
      },
    );
  }
}

// Keep the existing Google Maps button for backward compatibility
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
          return IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
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
            Color(0xFF4285F4),
            Color(0xFF1A73E8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
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

// Compact address section that always shows complete address
class _CompactFriendAddressSection extends StatefulWidget {
  final UserModel friend;
  const _CompactFriendAddressSection({required this.friend});

  @override
  State<_CompactFriendAddressSection> createState() => _CompactFriendAddressSectionState();
}

class _CompactFriendAddressSectionState extends State<_CompactFriendAddressSection> {
  Map<String, String?>? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void didUpdateWidget(_CompactFriendAddressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload address if friend data changed
    if (oldWidget.friend.id != widget.friend.id || 
        oldWidget.friend.lastLocation != widget.friend.lastLocation) {
      _loadAddress();
    }
  }

  void _loadAddress() async {
    final state = context.findAncestorStateOfType<_FriendsFamilyScreenState>();
    final friend = widget.friend;
    
    // Check both current location and last known location from LocationProvider
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.userLocations[friend.id];
    final lastKnownLocation = friend.lastLocation;
    
    // Use current location if available, otherwise use last known location
    final locationToUse = currentLocation ?? lastKnownLocation;
    
    if (locationToUse == null) return;
    
    final cache = state?._addressCache;
    final cacheKey = '${friend.id}_${locationToUse.latitude}_${locationToUse.longitude}';
    
    if (cache != null && cache.containsKey(cacheKey)) {
      setState(() {
        _address = cache[cacheKey];
      });
      return;
    }
    
    setState(() => _loading = true);
    final addr = await locationProvider.getAddressForCoordinates(
      locationToUse.latitude, 
      locationToUse.longitude
    );
    
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
    
    // Check both current location and last known location from LocationProvider
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.userLocations[friend.id];
    final lastKnownLocation = friend.lastLocation;
    
    // Use current location if available, otherwise use last known location
    final locationToUse = currentLocation ?? lastKnownLocation;
    
    if (locationToUse == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                friend.locationSharingEnabled 
                    ? 'Location not available yet' 
                    : 'Location sharing disabled',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Loading address...',
                style: TextStyle(fontSize: 11, color: Colors.blue),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_address == null || _address!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.location_searching, size: 12, color: Colors.orange[600]),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Address not found',
                style: TextStyle(fontSize: 11, color: Colors.orange),
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      );
    }
    
    final address = _address!['address'] ?? '';
    final city = _address!['city'] ?? '';
    final pin = _address!['postalCode'] ?? '';
    
    // Build complete address string
    final addressParts = <String>[];
    if (address.isNotEmpty) addressParts.add(address);
    if (city.isNotEmpty) addressParts.add(city);
    if (pin.isNotEmpty) addressParts.add(pin);
    
    final fullAddress = addressParts.join(', ');
    
    // Determine if this is current or last known location
    final isCurrentLocation = currentLocation != null;
    final isOnline = Provider.of<LocationProvider>(context, listen: false).isUserSharingLocation(friend.id);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentLocation && isOnline 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCurrentLocation && isOnline ? Icons.location_on : Icons.location_history,
                size: 12, 
                color: isCurrentLocation && isOnline ? Colors.green[600] : Colors.orange[600]
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  fullAddress.isNotEmpty ? fullAddress : 'Address available',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrentLocation && isOnline ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.visible, // Always show complete address
                  maxLines: null, // Allow multiple lines if needed
                ),
              ),
            ],
          ),
          // Show "last known" indicator for offline friends
          if (!isCurrentLocation || !isOnline)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                isCurrentLocation ? 'Current location' : 'Last known location',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Compact address section for friend list items
