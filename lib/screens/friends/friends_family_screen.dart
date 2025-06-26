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
    return Column(
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
                color: Colors.grey.withOpacity(0.2),
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
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
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
            color: Colors.grey.withOpacity(0.1),
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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
        color: isOn ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and text section with flexible sizing
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOn ? Icons.location_on : Icons.location_off,
                    size: 12,
                    color: isOn ? Colors.green : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isOn ? Colors.green : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Switch with fixed size
          SizedBox(
            width: 40,
            child: Transform.scale(
              scale: 0.6,
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
          ),
        ],
      ),
    );
  }

  void _handleToggle(bool value, LocationProvider locationProvider, firebase_auth.User user) async {
    print('Toggle pressed: $value, current tracking: ${locationProvider.isTracking}');
    
    // Prevent double-toggling
    if (value == locationProvider.isTracking) {
      print('Toggle value same as current state, ignoring');
      return;
    }
    
    try {
      if (value) {
        print('Starting location tracking for user: ${user.uid}');
        await locationProvider.startTracking(user.uid);
        if (mounted) {
          _showSnackBar('Location sharing turned ON - Friends can see your location', Colors.green, Icons.check_circle);
        }
      } else {
        print('Stopping location tracking');
        await locationProvider.stopTracking();
        if (mounted) {
          _showSnackBar('Location sharing turned OFF - You appear offline to friends', Colors.orange, Icons.location_off);
        }
      }
    } catch (e) {
      print('Error toggling location sharing: $e');
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red, Icons.error);
      }
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
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                          color: Colors.pink.withOpacity(0.3),
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
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline(friend) ? Colors.green : Colors.grey[400],
                          border: Border.all(color: Colors.white, width: 2),
                        ),
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
                                  ? Colors.purple.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: friendRelationship.category == FriendshipCategory.family 
                                    ? Colors.purple.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
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
                      
                      // Status Row
                      Row(
                        children: [
                          // Location sharing status
                          _CompactLocationStatusIndicator(friend: friend),
                          const SizedBox(width: 8),
                          // Last seen
                          Expanded(
                            child: Text(
                              _getLastSeenText(friend),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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

  bool _isOnline(UserModel friend) {
    if (friend.lastSeen == null) return false;
    return DateTime.now().difference(friend.lastSeen!).inMinutes < 5;
  }

  String _getLastSeenText(UserModel friend) {
    if (friend.lastSeen == null) return 'Never seen';
    
    final now = DateTime.now();
    final difference = now.difference(friend.lastSeen!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'Long time ago';
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
                ? Colors.green.withOpacity(0.1) 
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
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
                    color: const Color(0xFF4285F4).withOpacity(0.3),
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
              color: Colors.grey.withOpacity(0.15),
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
            Color(0xFF4285F4),
            Color(0xFF1A73E8),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'No location available',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
          color: Colors.blue.withOpacity(0.1),
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
          color: Colors.orange.withOpacity(0.1),
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
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 12, color: Colors.green[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fullAddress.isNotEmpty ? fullAddress : 'Address available',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.visible, // Always show complete address
              maxLines: null, // Allow multiple lines if needed
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the existing address section for backward compatibility
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