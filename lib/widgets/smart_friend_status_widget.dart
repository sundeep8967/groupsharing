import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Smart Friend Status Widget
/// 
/// Shows friend's location sharing status with intelligent indicators for:
/// - Sleep mode (😴)
/// - Idle mode (💤) 
/// - Active mode (🚶)
/// - Driving mode (🚗)
/// - Time since last location update
/// - Battery-optimized status messages
class SmartFriendStatusWidget extends StatelessWidget {
  final String friendId;
  final String friendName;
  final String? profileImageUrl;
  final bool isOnline;
  final bool isSharing;
  final LatLng? lastLocation;
  final DateTime? lastLocationUpdate;
  final String? trackingMode;
  final String? sleepState;
  final VoidCallback? onTap;

  const SmartFriendStatusWidget({
    Key? key,
    required this.friendId,
    required this.friendName,
    this.profileImageUrl,
    required this.isOnline,
    required this.isSharing,
    this.lastLocation,
    this.lastLocationUpdate,
    this.trackingMode,
    this.sleepState,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(),
        child: _getStatusIcon(),
        foregroundColor: Colors.white,
      ),
      title: Text(
        friendName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getSmartStatusText()),
          if (lastLocationUpdate != null)
            Text(
              _getLocationUpdateText(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: _getTrailingWidget(),
      onTap: onTap,
    );
  }

  /// Get status icon based on sleep state and sharing status
  Widget _getStatusIcon() {
    if (!isSharing) {
      return const Icon(Icons.location_off, size: 20);
    }

    switch (sleepState?.toLowerCase()) {
      case 'sleeping':
        return const Text('😴', style: TextStyle(fontSize: 16));
      case 'idle':
        return const Text('💤', style: TextStyle(fontSize: 16));
      case 'walking':
      case 'active':
        return const Text('🚶', style: TextStyle(fontSize: 16));
      case 'running':
        return const Icon(Icons.directions_run, size: 20);
      case 'in vehicle':
      case 'driving':
        return const Text('🚗', style: TextStyle(fontSize: 16));
      case 'on bicycle':
        return const Icon(Icons.directions_bike, size: 20);
      default:
        return const Icon(Icons.location_on, size: 20);
    }
  }

  /// Get status color based on sharing status and sleep state
  Color _getStatusColor() {
    if (!isOnline) return Colors.grey;
    if (!isSharing) return Colors.red;

    switch (sleepState?.toLowerCase()) {
      case 'sleeping':
        return Colors.blue;
      case 'idle':
        return Colors.orange;
      case 'walking':
      case 'running':
      case 'active':
        return Colors.green;
      case 'in vehicle':
      case 'driving':
        return Colors.purple;
      case 'on bicycle':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  /// Get smart status text that explains current state
  String _getSmartStatusText() {
    if (!isOnline) return 'Offline';
    if (!isSharing) return 'Not sharing location';

    switch (sleepState?.toLowerCase()) {
      case 'sleeping':
        return 'Sleeping • Location sharing active';
      case 'idle':
        return 'Idle • Location sharing active';
      case 'walking':
        return 'Walking • Location sharing active';
      case 'running':
        return 'Running • Location sharing active';
      case 'active':
        return 'Active • Location sharing active';
      case 'in vehicle':
      case 'driving':
        return 'Driving • Location sharing active';
      case 'on bicycle':
        return 'Cycling • Location sharing active';
      case 'still':
        return 'Stationary • Location sharing active';
      default:
        return 'Location sharing active';
    }
  }

  /// Get location update text with smart timing
  String _getLocationUpdateText() {
    if (lastLocationUpdate == null) return 'Location unknown';

    final now = DateTime.now();
    final difference = now.difference(lastLocationUpdate!);

    if (difference.inMinutes < 1) {
      return 'Location live';
    } else if (difference.inMinutes < 60) {
      return 'Updated ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Updated ${difference.inHours}h ago';
    } else {
      return 'Updated ${difference.inDays}d ago';
    }
  }

  /// Get trailing widget with battery optimization indicator
  Widget? _getTrailingWidget() {
    if (!isSharing) return null;

    // Show battery optimization indicator for sleep/idle modes
    if (sleepState?.toLowerCase() == 'sleeping' || 
        sleepState?.toLowerCase() == 'idle') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.battery_saver,
              size: 12,
              color: Colors.green[700],
            ),
            const SizedBox(width: 2),
            Text(
              'Eco',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }
}

/// Extension to create SmartFriendStatusWidget from location data
extension SmartFriendStatusExtension on Map<String, dynamic> {
  SmartFriendStatusWidget toSmartFriendStatus({
    required String friendId,
    required String friendName,
    String? profileImageUrl,
    VoidCallback? onTap,
  }) {
    return SmartFriendStatusWidget(
      friendId: friendId,
      friendName: friendName,
      profileImageUrl: profileImageUrl,
      isOnline: this['isOnline'] ?? false,
      isSharing: this['isSharing'] ?? false,
      lastLocation: this['location'] != null 
          ? LatLng(this['location']['lat'], this['location']['lng'])
          : null,
      lastLocationUpdate: this['lastLocationUpdate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(this['lastLocationUpdate'])
          : null,
      trackingMode: this['trackingMode'],
      sleepState: this['sleepState'],
      onTap: onTap,
    );
  }
}