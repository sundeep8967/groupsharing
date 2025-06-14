import 'package:flutter/material.dart';

// Data model for a friend request
class FriendRequest {
  final String name;
  final String username;
  final String avatarUrl;

  FriendRequest({
    required this.name,
    required this.username,
    required this.avatarUrl,
  });
}

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  // State variable to manage the selected tab (0 = Received, 1 = Sent)
  int _selectedTabIndex = 0;

  // Sample data for friend requests
  final List<FriendRequest> _receivedRequests = [
    FriendRequest(
      name: 'Jessica Miller',
      username: '@jessica.miller',
      avatarUrl: 'assets/images/avatars/jessica_miller.png',
    ),
    FriendRequest(
      name: 'David Lee',
      username: '@david.lee',
      avatarUrl: 'assets/images/avatars/david_lee.png',
    ),
    FriendRequest(
      name: 'Emily Chen',
      username: '@emily.chen',
      avatarUrl: 'assets/images/avatars/emily_chen.png',
    ),
  ];

  final List<FriendRequest> _sentRequests = [
    FriendRequest(
      name: 'Michael Brown',
      username: '@michael.brown',
      avatarUrl: 'assets/images/avatars/michael_brown.png',
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
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Friend Requests',
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
            onPressed: () {
              // TODO: Implement settings action
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Received'),
                    _buildTabButton(1, 'Sent'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _selectedTabIndex == 0 ? _receivedRequests.length : _sentRequests.length,
                itemBuilder: (context, index) {
                  final request = _selectedTabIndex == 0 ? _receivedRequests[index] : _sentRequests[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: FriendRequestListItem(request: request),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: colorScheme.surface,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavBarItem(Icons.map_outlined, 'Map', false),
              _buildNavBarItem(Icons.people_alt_outlined, 'Friends', true, badgeCount: 3),
              _buildNavBarItem(Icons.add_circle_outline, 'Add', false),
              _buildNavBarItem(Icons.notifications_none, 'Activity', false),
              _buildNavBarItem(Icons.settings_outlined, 'Settings', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String text) {
    final bool isSelected = _selectedTabIndex == index;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _selectedTabIndex = index),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? colorScheme.primary : Colors.transparent,
          foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, bool isActive, {int? badgeCount}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        // TODO: Implement navigation logic
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(
                    icon,
                    color: isActive ? colorScheme.secondary : colorScheme.onTertiary,
                    size: 24,
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? colorScheme.secondary : colorScheme.onTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestListItem extends StatelessWidget {
  final FriendRequest request;
  const FriendRequestListItem({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: AssetImage(request.avatarUrl),
            backgroundColor: Colors.grey.shade200,
            onBackgroundImageError: (_, __) {
              // Handle image loading error
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                Text(
                  request.username,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement accept logic
              debugPrint('Accepted ${request.name}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text('Accept'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              // TODO: Implement decline logic
              debugPrint('Declined ${request.name}');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onTertiary,
              side: BorderSide(color: colorScheme.tertiary, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
