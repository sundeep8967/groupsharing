import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/location_model.dart';
import '../../services/friend_service.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../widgets/smooth_modern_map.dart';
import '../../models/map_marker.dart';

class GoogleFamilyDashboardScreen extends StatefulWidget {
  const GoogleFamilyDashboardScreen({Key? key}) : super(key: key);

  @override
  State<GoogleFamilyDashboardScreen> createState() => _GoogleFamilyDashboardScreenState();
}

class _GoogleFamilyDashboardScreenState extends State<GoogleFamilyDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  
  List<UserModel> _familyMembers = [];
  Map<String, LocationModel?> _memberLocations = {};
  bool _isLoading = true;
  String? _currentUserId;

  latlong.LatLng _computeInitialCenter() {
    if (_memberLocations.isEmpty) {
      return const latlong.LatLng(37.7749, -122.4194);
    }
    final valid = _memberLocations.values.whereType<LocationModel>().toList();
    if (valid.isEmpty) {
      return const latlong.LatLng(37.7749, -122.4194);
    }
    double sumLat = 0;
    double sumLng = 0;
    for (final loc in valid) {
      sumLat += loc.latitude;
      sumLng += loc.longitude;
    }
    return latlong.LatLng(sumLat / valid.length, sumLng / valid.length);
  }

  latlong.LatLng? _getCurrentUserLocation() {
    final current = _currentUserId != null ? _memberLocations[_currentUserId!] : null;
    if (current == null) return null;
    return latlong.LatLng(current.latitude, current.longitude);
  }

  Set<MapMarker> _buildMarkers() {
    final markers = <MapMarker>{};
    for (final member in _familyMembers) {
      final location = _memberLocations[member.uid];
      if (location == null) continue;
      markers.add(MapMarker(
        id: member.uid,
        point: latlong.LatLng(location.latitude, location.longitude),
        label: member.displayName,
      ));
    }
    return markers;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
        await _loadFamilyMembers();
        // _loadMemberLocations() will be called from the stream listener
      }
    } catch (e) {
      print('Error initializing family dashboard: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      // Load family members (friends with family relationship)
      _friendService.getFriends(_currentUserId!).listen((friends) {
        if (mounted) {
          setState(() {
            _familyMembers = friends.where((friend) => 
              friend.relationship == 'family' || friend.relationship == 'spouse' || 
              friend.relationship == 'child' || friend.relationship == 'parent'
            ).toList();
          });
          // Load locations after getting friends
          _loadMemberLocations();
        }
      });
    } catch (e) {
      print('Error loading family members: $e');
    }
  }

  Future<void> _loadMemberLocations() async {
    try {
      for (final member in _familyMembers) {
        final location = await _getLatestLocation(member.uid);
        setState(() {
          _memberLocations[member.uid] = location;
        });
      }
    } catch (e) {
      print('Error loading member locations: $e');
    }
  }

  Future<LocationModel?> _getLatestLocation(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return LocationModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
    } catch (e) {
      print('Error getting latest location for $userId: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        title: const Text(
          'Family Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Map', icon: Icon(Icons.map)),
            Tab(text: 'Members', icon: Icon(Icons.people)),
            Tab(text: 'Activity', icon: Icon(Icons.timeline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMapView(),
                _buildMembersView(),
                _buildActivityView(),
              ],
            ),
    );
  }

  Widget _buildMapView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Map controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Search places...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF2A2A2A),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SmoothModernMap(
                  initialPosition: _computeInitialCenter(),
                  userLocation: _getCurrentUserLocation(),
                  markers: _buildMarkers(),
                  showUserLocation: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMembersView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Family Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_familyMembers.length} members',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Members list
          Expanded(
            child: _familyMembers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      final member = _familyMembers[index];
                      final location = _memberLocations[member.uid];
                      return _buildMemberCard(member, location);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel member, LocationModel? location) {
    final isOnline = location != null && 
        DateTime.now().difference(location.timestamp).inMinutes < 15;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? const Color(0xFF4CAF50) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: member.profileImageUrl != null
                    ? NetworkImage(member.profileImageUrl!)
                    : null,
                child: member.profileImageUrl == null
                    ? Text(
                        member.displayName.isNotEmpty 
                            ? member.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Member info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRelationshipText(member.relationship),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                if (location != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _getLocationText(location),
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showMemberDetails(member, location),
                icon: const Icon(Icons.info_outline, color: Colors.grey),
              ),
              IconButton(
                onPressed: () => _callMember(member),
                icon: const Icon(Icons.phone, color: Color(0xFF4CAF50)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityView() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Activity list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 10, // Mock data
              itemBuilder: (context, index) {
                return _buildActivityItem(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(int index) {
    final activities = [
      {'icon': Icons.location_on, 'text': 'Sarah arrived at Home', 'time': '2 min ago'},
      {'icon': Icons.directions_car, 'text': 'John started driving', 'time': '15 min ago'},
      {'icon': Icons.home, 'text': 'Mom left Work', 'time': '1 hour ago'},
      {'icon': Icons.school, 'text': 'Emma arrived at School', 'time': '2 hours ago'},
      {'icon': Icons.shopping_cart, 'text': 'Dad at Grocery Store', 'time': '3 hours ago'},
    ];

    final activity = activities[index % activities.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity['icon'] as IconData,
              color: const Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['text'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['time'] as String,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.family_restroom,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No Family Members',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add family members to see them here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to add friends screen
              Navigator.pushNamed(context, '/add-friends');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add Family Members'),
          ),
        ],
      ),
    );
  }

  String _getRelationshipText(String? relationship) {
    switch (relationship?.toLowerCase()) {
      case 'spouse':
        return 'Spouse';
      case 'child':
        return 'Child';
      case 'parent':
        return 'Parent';
      case 'family':
        return 'Family';
      default:
        return 'Family Member';
    }
  }

  String _getLocationText(LocationModel location) {
    final timeDiff = DateTime.now().difference(location.timestamp);
    if (timeDiff.inMinutes < 5) {
      return 'Live location';
    } else if (timeDiff.inMinutes < 60) {
      return '${timeDiff.inMinutes} min ago';
    } else if (timeDiff.inHours < 24) {
      return '${timeDiff.inHours} hours ago';
    } else {
      return '${timeDiff.inDays} days ago';
    }
  }

  void _showMemberDetails(UserModel member, LocationModel? location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Member info
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: member.profileImageUrl != null
                    ? NetworkImage(member.profileImageUrl!)
                    : null,
                child: member.profileImageUrl == null
                    ? Text(
                        member.displayName.isNotEmpty 
                            ? member.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                member.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getRelationshipText(member.relationship),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              if (location != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last seen: ${_getLocationText(location)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.speed, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Speed: ${location.speed?.toStringAsFixed(1) ?? '0'} km/h',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callMember(member),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _messageMember(member),
                      icon: const Icon(Icons.message),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _callMember(UserModel member) {
    // Implement call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${member.displayName}...'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  void _messageMember(UserModel member) {
    // Navigate to chat screen
    Navigator.pushNamed(context, '/chat', arguments: member);
  }
}