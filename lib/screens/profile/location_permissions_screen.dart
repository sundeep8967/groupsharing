import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/comprehensive_permission_service.dart';

class LocationPermissionsScreen extends StatefulWidget {
  const LocationPermissionsScreen({super.key});

  @override
  State<LocationPermissionsScreen> createState() => _LocationPermissionsScreenState();
}

class _LocationPermissionsScreenState extends State<LocationPermissionsScreen> {
  bool _isPublic = true;
  List<String> _blockedUsers = [];
  bool _isLoading = true;
  bool _busy = false;
  Map<String, dynamic> _permStatus = const {
    'permissions': {
      'location_basic': false,
      'location_background': false,
      'notifications': false,
      'battery_optimization': true,
      'ios_background_refresh': true,
    },
    'allGranted': false,
  };

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refreshPermissionStatuses();
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

  Future<void> _refreshPermissionStatuses() async {
    setState(() => _busy = true);
    try {
      final status = await ComprehensivePermissionService.getDetailedPermissionStatus();
      if (mounted) setState(() => _permStatus = status);
    } catch (e) {
      // ignore, keep defaults
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantAll() async {
    setState(() => _busy = true);
    try {
      final ok = await ComprehensivePermissionService.requestAllPermissions();
      if (mounted) {
        await _refreshPermissionStatuses();
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some permissions still missing. You may need to grant them in system settings.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSystemSettings() async {
    await ComprehensivePermissionService.openSystemAppSettings();
  }

  Widget _statusTile({
    required String title,
    required bool ok,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: ok ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          color: ok ? Colors.green.shade700 : Colors.red.shade700,
          size: 20,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.green),
            tooltip: 'Open Map',
            onPressed: () {
              Navigator.of(context).pushNamed('/main');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-check permissions',
            onPressed: _busy ? null : _refreshPermissionStatuses,
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Required permissions for background location sharing',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _statusTile(
                  title: 'Location (While in use)',
                  ok: (_permStatus['permissions']?['location_basic'] as bool?) ?? false,
                  subtitle: 'Required to access location',
                  onTap: () async {
                    await Permission.location.request();
                    _refreshPermissionStatuses();
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _statusTile(
                  title: 'Background Location (Allow all the time)',
                  ok: (_permStatus['permissions']?['location_background'] as bool?) ?? false,
                  subtitle: 'Required to share location in background',
                  onTap: () async {
                    await Permission.locationAlways.request();
                    _refreshPermissionStatuses();
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _statusTile(
                  title: 'Notifications',
                  ok: (_permStatus['permissions']?['notifications'] as bool?) ?? false,
                  subtitle: Platform.isAndroid ? 'Android 13+ requires notification permission' : null,
                  onTap: () async {
                    await Permission.notification.request();
                    _refreshPermissionStatuses();
                  },
                ),
                if (Platform.isAndroid) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  _statusTile(
                    title: 'Battery Optimization Disabled',
                    ok: (_permStatus['permissions']?['battery_optimization'] as bool?) ?? false,
                    subtitle: 'Disable optimization to allow background updates',
                    onTap: () async {
                      await Permission.ignoreBatteryOptimizations.request();
                      _refreshPermissionStatuses();
                    },
                  ),
                ],
                if (Platform.isIOS) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  _statusTile(
                    title: 'Background App Refresh',
                    ok: (_permStatus['permissions']?['ios_background_refresh'] as bool?) ?? true,
                    subtitle: 'Keep enabled for best reliability',
                    onTap: _openSystemSettings,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _grantAll,
                    icon: const Icon(Icons.shield_moon),
                    label: const Text('Grant All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openSystemSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Open App Settings'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
