import 'dart:developer' as developer;
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';

/// Service for detecting when friends are within proximity range
/// and triggering appropriate notifications
class ProximityService {
  // Proximity threshold in meters
  static const double _proximityThreshold = 500.0; // 500 meters
  
  // Track which friends are currently in proximity to avoid duplicate notifications
  static final Set<String> _friendsInProximity = <String>{};
  
  /// Calculate distance between two coordinates in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  /// Check proximity for all friends and trigger notifications if needed
  static Future<void> checkProximityForAllFriends({
    required LatLng userLocation,
    required Map<String, LatLng> friendLocations,
    required Map<String, bool> friendSharingStatus,
    required String currentUserId,
  }) async {
    try {
      developer.log('Checking proximity for ${friendLocations.length} friends');
      
      // Track friends who are currently in range
      final Set<String> currentlyInRange = <String>{};
      
      for (final entry in friendLocations.entries) {
        final friendId = entry.key;
        final friendLocation = entry.value;
        
        // Skip current user
        if (friendId == currentUserId) continue;
        
        // Skip friends who are not sharing location
        if (friendSharingStatus[friendId] != true) continue;
        
        // Calculate distance
        final distanceInMeters = calculateDistance(userLocation, friendLocation);
        
        developer.log('Distance to friend $friendId: ${distanceInMeters.round()}m');
        
        // Check if friend is within proximity threshold
        if (distanceInMeters <= _proximityThreshold) {
          currentlyInRange.add(friendId);
          
          // If friend was not in proximity before, show notification
          if (!_friendsInProximity.contains(friendId)) {
            developer.log('Friend $friendId entered proximity range (${distanceInMeters.round()}m)');
            
            await NotificationService.showProximityNotificationWithName(
              friendId: friendId,
              distanceInMeters: distanceInMeters,
            );
          }
        }
      }
      
      // Update friends in proximity set
      // Remove friends who are no longer in range
      final friendsWhoLeft = _friendsInProximity.difference(currentlyInRange);
      for (final friendId in friendsWhoLeft) {
        developer.log('Friend $friendId left proximity range');
        _friendsInProximity.remove(friendId);
      }
      
      // Add friends who are now in range
      _friendsInProximity.addAll(currentlyInRange);
      
      developer.log('Friends currently in proximity: ${_friendsInProximity.length}');
      
    } catch (e) {
      developer.log('Error checking proximity: $e');
    }
  }
  
  /// Check proximity for a specific friend
  static Future<void> checkProximityForFriend({
    required LatLng userLocation,
    required String friendId,
    required LatLng friendLocation,
    required bool isFriendSharingLocation,
  }) async {
    try {
      // Skip if friend is not sharing location
      if (!isFriendSharingLocation) {
        // Remove from proximity set if they were there
        if (_friendsInProximity.contains(friendId)) {
          _friendsInProximity.remove(friendId);
          developer.log('Friend $friendId removed from proximity (stopped sharing)');
        }
        return;
      }
      
      // Calculate distance
      final distanceInMeters = calculateDistance(userLocation, friendLocation);
      
      // Check if friend is within proximity threshold
      if (distanceInMeters <= _proximityThreshold) {
        // If friend was not in proximity before, show notification
        if (!_friendsInProximity.contains(friendId)) {
          developer.log('Friend $friendId entered proximity range (${distanceInMeters.round()}m)');
          
          _friendsInProximity.add(friendId);
          
          await NotificationService.showProximityNotificationWithName(
            friendId: friendId,
            distanceInMeters: distanceInMeters,
          );
        }
      } else {
        // Friend is outside proximity range
        if (_friendsInProximity.contains(friendId)) {
          _friendsInProximity.remove(friendId);
          developer.log('Friend $friendId left proximity range');
        }
      }
      
    } catch (e) {
      developer.log('Error checking proximity for friend $friendId: $e');
    }
  }
  
  /// Get friends currently in proximity
  static Set<String> getFriendsInProximity() {
    return Set<String>.from(_friendsInProximity);
  }
  
  /// Check if a specific friend is in proximity
  static bool isFriendInProximity(String friendId) {
    return _friendsInProximity.contains(friendId);
  }
  
  /// Clear proximity tracking (useful for testing or when user stops sharing)
  static void clearProximityTracking() {
    _friendsInProximity.clear();
    developer.log('Proximity tracking cleared');
  }
  
  /// Get proximity threshold in meters
  static double getProximityThreshold() {
    return _proximityThreshold;
  }
  
  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 100) {
      return '${distanceInMeters.round()}m';
    } else if (distanceInMeters < 1000) {
      return '${(distanceInMeters / 100).round() * 100}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }
  
  /// Calculate bearing between two points (for future directional notifications)
  static double calculateBearing(LatLng from, LatLng to) {
    final lat1Rad = from.latitude * (pi / 180);
    final lat2Rad = to.latitude * (pi / 180);
    final deltaLngRad = (to.longitude - from.longitude) * (pi / 180);
    
    final y = sin(deltaLngRad) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);
    
    final bearingRad = atan2(y, x);
    final bearingDeg = bearingRad * (180 / pi);
    
    return (bearingDeg + 360) % 360; // Normalize to 0-360 degrees
  }
  
  /// Get cardinal direction from bearing
  static String getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}