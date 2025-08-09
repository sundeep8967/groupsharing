import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../models/friendship_model.dart';
import '../../services/friend_service.dart';
import '../../providers/location_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/presence_service.dart';
import 'package:provider/provider.dart';

/// Screen that displays detailed information about a friend
/// This screen uses simple database fetches (no real-time updates) for better performance
class FriendDetailsScreen extends StatefulWidget {
  final String friendId; // Friend's user ID
  final String friendName; // Friend's display name (for app bar)
  final String? friendshipId; // Friendship document ID for category updates
  final FriendshipCategory? currentCategory; // Current category

  const FriendDetailsScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendshipId,
    this.currentCategory,
  });

  @override
  State<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends State<FriendDetailsScreen> {
  final FriendService _friendService = FriendService();
  
  // State variables for friend data
  UserModel? _friendData;
  Map<String, String?>? _addressData;
  bool _isLoadingFriend = true;
  bool _isLoadingAddress = false;
  String? _errorMessage;
  FriendshipCategory? _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.currentCategory ?? FriendshipCategory.family;
    // Load friend details when screen opens
    _loadFriendDetails();
  }

  /// Loads friend details from database (one-time fetch, no real-time updates)
  Future<void> _loadFriendDetails() async {
    try {
      setState(() {
        _isLoadingFriend = true;
        _errorMessage = null;
      });

      // Fetch friend data from database
      final friendData = await _friendService.getUserDetails(widget.friendId);
      
      if (friendData == null) {
        setState(() {
          _errorMessage = 'Friend not found';
          _isLoadingFriend = false;
        });
        return;
      }

      setState(() {
        _friendData = friendData;
        _isLoadingFriend = false;
      });

      // Load address if friend has location data
      if (friendData.lastLocation != null) {
        _loadAddressDetails();
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load friend details: $e';
        _isLoadingFriend = false;
      });
    }
  }

  /// Loads address details for friend's last known location
  Future<void> _loadAddressDetails() async {
    if (_friendData?.lastLocation == null) return;

    try {
      setState(() => _isLoadingAddress = true);

      // Get address from coordinates using location provider
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      final address = await locationProvider.getAddressForCoordinates(
        _friendData!.lastLocation!.latitude,
        _friendData!.lastLocation!.longitude,
      );

      if (mounted) {
        setState(() {
          _addressData = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.friendName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Refresh button to reload friend data
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriendDetails,
            tooltip: 'Refresh',
          ),
          // Menu button with unfriend option
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unfriend') {
                _showUnfriendDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'unfriend',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove Friend', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  /// Builds the main body content based on loading state
  Widget _buildBody() {
    // Show loading indicator while fetching friend data
    if (_isLoadingFriend) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading friend details...'),
          ],
        ),
      );
    }

    // Show error message if loading failed
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriendDetails,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Show friend details if data loaded successfully
    if (_friendData != null) {
      return RefreshIndicator(
        onRefresh: _loadFriendDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          child: _buildFriendDetails(),
        ),
      );
    }

    // Fallback state (should not happen)
    return const Center(
      child: Text('No data available'),
    );
  }

  /// Builds the detailed friend information layout
  Widget _buildFriendDetails() {
    final friend = _friendData!;

    return Column(
      children: [
        // Hero profile section at the top
        _buildHeroProfileSection(friend),
        
        const SizedBox(height: 20),
        
        // Category management card
        _buildCategoryCard(),
        
        const SizedBox(height: 20),
        
        // Quick stats row
        _buildQuickStatsRow(friend),
        
        const SizedBox(height: 20),
        
        // Location information card
        if (friend.lastLocation != null) ...[
          _buildLocationCard(friend),
          const SizedBox(height: 20),
        ],
        
        // Action buttons
        _buildActionButtons(friend),
      ],
    );
  }

  /// Builds the hero profile section with gradient background
  Widget _buildHeroProfileSection(UserModel friend) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile photo with glow effect
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 46,
                backgroundImage: friend.photoUrl != null
                    ? CachedNetworkImageProvider(
                        friend.photoUrl!,
                        cacheKey: 'profile_${friend.id}',
                      )
                    : null,
                child: friend.photoUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Name with white text
          Text(
            friend.displayName ?? 'Unknown',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Email with semi-transparent white
          Text(
            friend.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Online status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isOnline(friend) ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline(friend) ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _getOnlineStatus(friend),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the category management card
  Widget _buildCategoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _currentCategory == FriendshipCategory.family 
                ? Colors.purple.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
            _currentCategory == FriendshipCategory.family 
                ? Colors.purple.withValues(alpha: 0.05)
                : Colors.blue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentCategory == FriendshipCategory.family 
              ? Colors.purple.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _currentCategory == FriendshipCategory.family 
                    ? Icons.family_restroom 
                    : Icons.people,
                color: _currentCategory == FriendshipCategory.family 
                    ? Colors.purple 
                    : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Relationship Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Current category display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentCategory == FriendshipCategory.family 
                  ? Colors.purple.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentCategory == FriendshipCategory.family 
                    ? Colors.purple.withValues(alpha: 0.3)
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentCategory == FriendshipCategory.family 
                      ? Icons.family_restroom 
                      : Icons.people,
                  size: 16,
                  color: _currentCategory == FriendshipCategory.family 
                      ? Colors.purple[700]
                      : Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  _getCategoryDisplayName(_currentCategory!),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _currentCategory == FriendshipCategory.family 
                        ? Colors.purple[700]
                        : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Category toggle buttons
          if (widget.friendshipId != null) ...[
            const Text(
              'Change category:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryButton(
                    category: FriendshipCategory.family,
                    icon: Icons.family_restroom,
                    label: 'Family',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryButton(
                    category: FriendshipCategory.friend,
                    icon: Icons.people,
                    label: 'Friend',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Category cannot be changed at this time.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a category selection button
  Widget _buildCategoryButton({
    required FriendshipCategory category,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentCategory == category;
    
    return ElevatedButton.icon(
      onPressed: isSelected ? null : () => _updateCategory(category),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : color.withValues(alpha: 0.1),
        foregroundColor: isSelected ? Colors.white : color,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withValues(alpha: isSelected ? 0 : 0.3),
          ),
        ),
      ),
    );
  }

  /// Builds quick stats row with key information
  Widget _buildQuickStatsRow(UserModel friend) {
    return Row(
      children: [
        // Location sharing status
        Expanded(
          child: _buildStatCard(
            icon: Icons.location_on,
            label: 'Location',
            value: friend.locationSharingEnabled ? 'Shared' : 'Private',
            color: friend.locationSharingEnabled ? Colors.green : Colors.orange,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Last seen
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time,
            label: 'Last Seen',
            value: friend.lastSeen != null ? _formatLastSeen(friend.lastSeen!) : 'Unknown',
            color: Colors.blue,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Friend code
        Expanded(
          child: _buildStatCard(
            icon: Icons.qr_code,
            label: 'Friend Code',
            value: friend.friendCode ?? 'N/A',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  /// Builds a single stat card
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Builds the location information card
  Widget _buildLocationCard(UserModel friend) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.blue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Location Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Google Maps button
              IconButton(
                onPressed: _openInGoogleMaps,
                icon: const Icon(Icons.map, color: Colors.blue),
                tooltip: 'Open in Google Maps',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Coordinates
          _buildInfoTile(
            icon: Icons.gps_fixed,
            title: 'Coordinates',
            subtitle: '${friend.lastLocation!.latitude.toStringAsFixed(6)}, ${friend.lastLocation!.longitude.toStringAsFixed(6)}',
          ),
          
          const SizedBox(height: 12),
          
          // Address
          _buildAddressInfoTile(),
        ],
      ),
    );
  }

  /// Builds action buttons at the bottom
  Widget _buildActionButtons(UserModel friend) {
    return Row(
      children: [
        // Refresh button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loadFriendDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Google Maps button (if location available)
        if (friend.lastLocation != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.map),
              label: const Text('View on Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds address information tile with loading state
  Widget _buildAddressInfoTile() {
    if (_isLoadingAddress) {
      return _buildInfoTile(
        icon: Icons.home,
        title: 'Address',
        subtitle: 'Loading address...',
        trailing: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_addressData == null || _addressData!.isEmpty) {
      return _buildInfoTile(
        icon: Icons.home,
        title: 'Address',
        subtitle: 'Address not available',
      );
    }

    final address = _addressData!['address'] ?? '';
    final city = _addressData!['city'] ?? '';
    final postalCode = _addressData!['postalCode'] ?? '';
    
    final fullAddress = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty) city,
      if (postalCode.isNotEmpty) postalCode,
    ].join(', ');

    return _buildInfoTile(
      icon: Icons.home,
      title: 'Address',
      subtitle: fullAddress.isNotEmpty ? fullAddress : 'Address not available',
    );
  }

  /// Builds a modern info tile with icon, title, and subtitle
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Opens Google Maps with friend's location
  Future<void> _openInGoogleMaps() async {
    if (_friendData?.lastLocation == null) return;

    final lat = _friendData!.lastLocation!.latitude;
    final lng = _friendData!.lastLocation!.longitude;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening maps: $e')),
        );
      }
    }
  }

  /// Updates the friendship category
  Future<void> _updateCategory(FriendshipCategory newCategory) async {
    if (widget.friendshipId == null) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Update category in Firebase
      await _friendService.updateFriendshipCategory(widget.friendshipId!, newCategory);
      
      // Update local state
      setState(() {
        _currentCategory = newCategory;
      });
      
      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category updated to ${_getCategoryDisplayName(newCategory)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update category: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Determines if friend is currently online based on location sharing status
  bool _isOnline(UserModel friend) {
    final userData = {
      'locationSharingEnabled': friend.locationSharingEnabled,
      'lastLocationUpdate': friend.lastSeen?.millisecondsSinceEpoch,
      'lastSeen': friend.lastSeen?.millisecondsSinceEpoch,
    };
    return PresenceService.isUserOnline(userData);
  }

  /// Gets online status text based on location sharing
  String _getOnlineStatus(UserModel friend) {
    if (!friend.locationSharingEnabled) {
      return 'Location not shared';
    }
    return _isOnline(friend) ? 'Sharing location' : 'Location sharing inactive';
  }

  /// Formats last seen time in a user-friendly way
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return _formatDate(lastSeen);
    }
  }

  /// Formats date in a readable format
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Gets display name for category
  String _getCategoryDisplayName(FriendshipCategory category) {
    switch (category) {
      case FriendshipCategory.family:
        return 'Family';
      case FriendshipCategory.friend:
        return 'Friend';
    }
  }

  /// Shows confirmation dialog for unfriending
  void _showUnfriendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Are you sure you want to remove ${widget.friendName} from your friends list? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unfriendUser();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Removes the friend and navigates back
  Future<void> _unfriendUser() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Remove friend using the service
      await _friendService.removeFriend(currentUser.uid, widget.friendId);

      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.friendName} has been removed from your friends'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate back to friends list
        Navigator.of(context).pop();
      }

    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove friend: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}