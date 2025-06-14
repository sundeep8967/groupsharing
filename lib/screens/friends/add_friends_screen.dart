import 'package:flutter/material.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  // Sample data for demonstration
  final List<Map<String, dynamic>> _receivedRequests = [
    {
      'id': '1',
      'name': 'Alex Johnson',
      'username': '@alexj',
      'avatar': 'A',
      'time': '2h ago',
    },
    {
      'id': '2',
      'name': 'Sarah Wilson',
      'username': '@sarahw',
      'avatar': 'S',
      'time': '1d ago',
    },
  ];

  final List<Map<String, dynamic>> _sentRequests = [
    {
      'id': '3',
      'name': 'Mike Chen',
      'username': '@mikec',
      'avatar': 'M',
      'time': '3h ago',
      'status': 'Pending',
    },
    {
      'id': '4',
      'name': 'Emma Davis',
      'username': '@emmad',
      'avatar': 'E',
      'time': '2d ago',
      'status': 'Pending',
    },
  ];

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

  void _addFriend() {
    if (_searchController.text.isNotEmpty) {
      print('Searching for and adding friend: ${_searchController.text}');
      _searchController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username or name to add.')),
      );
    }
  }

  void _acceptRequest(String requestId) {
    setState(() {
      _receivedRequests.removeWhere((req) => req['id'] == requestId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request accepted!')),
    );
  }

  void _declineRequest(String requestId) {
    setState(() {
      _receivedRequests.removeWhere((req) => req['id'] == requestId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request declined')),
    );
  }

  void _cancelRequest(String requestId) {
    setState(() {
      _sentRequests.removeWhere((req) => req['id'] == requestId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request cancelled')),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request, {bool isReceived = true}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          child: Text(
            request['avatar'],
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          request['name'],
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${request['username']} • ${request['time']}',
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
                    onPressed: () => _acceptRequest(request['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () => _declineRequest(request['id']),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request['status'],
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _cancelRequest(request['id']),
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
        body: Column(
          children: [
            // Search and Add Friend Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search input field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by username or name...',
                              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                            ),
                            onSubmitted: (value) => _addFriend(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Add Friend Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addFriend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                      label: const Text(
                        'Add Friend',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Divider(height: 1, color: colorScheme.surfaceVariant),
            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Received Requests Tab
                  _receivedRequests.isEmpty
                      ? _buildEmptyState('No friend requests received yet.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _receivedRequests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestItem(
                              _receivedRequests[index],
                              isReceived: true,
                            );
                          },
                        ),
                  // Sent Requests Tab
                  _sentRequests.isEmpty
                      ? _buildEmptyState('No pending friend requests.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sentRequests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestItem(
                              _sentRequests[index],
                              isReceived: false,
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
