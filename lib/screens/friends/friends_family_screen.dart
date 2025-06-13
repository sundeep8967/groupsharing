import 'package:flutter/material.dart';

class Friend {
  final String name;
  final String status;
  final String avatarUrl;
  final String mapPreviewUrl;
  final bool isOnline;

  Friend({
    required this.name,
    required this.status,
    required this.avatarUrl,
    required this.mapPreviewUrl,
    required this.isOnline,
  });
}

class FriendsFamilyScreen extends StatefulWidget {
  const FriendsFamilyScreen({super.key});

  @override
  State<FriendsFamilyScreen> createState() => _FriendsFamilyScreenState();
}

class _FriendsFamilyScreenState extends State<FriendsFamilyScreen> {
  // State variable to manage the selected filter button (0=All, 1=Family, 2=Friends)
  int _selectedFilterIndex = 0;

  // Sample data for the list of friends/family members
  final List<Friend> _friends = [
    Friend(
      name: 'John Doe',
      status: 'Online - Last seen: 5 mins ago',
      avatarUrl: 'assets/images/avatars/john_doe.png',
      mapPreviewUrl: 'assets/images/map_previews/map_preview_1.png',
      isOnline: true,
    ),
    Friend(
      name: 'Jane Smith',
      status: 'Offline - Last updated: San Francisco, 2 hours ago',
      avatarUrl: 'assets/images/avatars/jane_smith.png',
      mapPreviewUrl: 'assets/images/map_previews/map_preview_2.png',
      isOnline: false,
    ),
    Friend(
      name: 'Mike Johnson',
      status: 'Online - At Home',
      avatarUrl: 'assets/images/avatars/mike_johnson.png',
      mapPreviewUrl: 'assets/images/map_previews/map_preview_3.png',
      isOnline: true,
    ),
    Friend(
      name: 'Emily Davis',
      status: 'Offline - Location sharing paused',
      avatarUrl: 'assets/images/avatars/emily_davis.png',
      mapPreviewUrl: 'assets/images/map_previews/map_preview_4.png',
      isOnline: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: colorScheme.onSurface),
          onPressed: () {},
        ),
        title: Text(
          'Friends & Family',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(colorScheme),
                  const SizedBox(height: 16),
                  _buildFilterButtons(colorScheme),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildFriendItem(_friends[index], colorScheme),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search friends or family...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.location_on_outlined,
              color: colorScheme.onSecondary,
              size: 24,
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButtons(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildFilterButton(0, 'All', colorScheme),
          _buildFilterButton(1, 'Family', colorScheme),
          _buildFilterButton(2, 'Friends', colorScheme),
        ],
      ),
    );
  }

  Widget _buildFilterButton(int index, String text, ColorScheme colorScheme) {
    final bool isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() {
            _selectedFilterIndex = index;
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? colorScheme.primary : Colors.transparent,
          foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendItem(Friend friend, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage(friend.avatarUrl),
                backgroundColor: Colors.grey.shade200,
                child: friend.avatarUrl.isEmpty
                    ? Icon(Icons.person, color: Colors.grey[600])
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: friend.isOnline ? Colors.green[500] : Colors.grey[400],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  friend.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 64,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Image.asset(
              friend.mapPreviewUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.map_outlined,
                    color: Colors.grey[400],
                    size: 30,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
