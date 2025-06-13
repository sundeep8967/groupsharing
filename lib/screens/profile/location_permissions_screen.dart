import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

class LocationPermissionsScreen extends StatefulWidget {
  const LocationPermissionsScreen({super.key});

  @override
  State<LocationPermissionsScreen> createState() => _LocationPermissionsScreenState();
}

class _LocationPermissionsScreenState extends State<LocationPermissionsScreen> {
  bool _isPublic = true;
  bool _shareWithFriends = true;
  List<String> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    final doc = await FirebaseService.firestore
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _isPublic = data['locationPublic'] ?? true;
        _shareWithFriends = data['shareWithFriends'] ?? true;
        _blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        _isLoading = false;
      });
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isLoading = true);

    try {
      final userId = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      await FirebaseService.firestore.collection('users').doc(userId).update({
        'locationPublic': _isPublic,
        'shareWithFriends': _shareWithFriends,
        'blockedUsers': _blockedUsers,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating permissions: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Permissions'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Public Location'),
            subtitle: const Text(
              'Allow anyone to see your location',
            ),
            value: _isPublic,
            onChanged: (bool value) {
              setState(() => _isPublic = value);
              _savePermissions();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Share with Friends'),
            subtitle: const Text(
              'Allow friends to see your location',
            ),
            value: _shareWithFriends,
            onChanged: (bool value) {
              setState(() => _shareWithFriends = value);
              _savePermissions();
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Blocked Users'),
            subtitle: Text(
              '${_blockedUsers.length} users blocked',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to blocked users screen
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Users you\'ve blocked won\'t be able to see your location or send you friend requests.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
