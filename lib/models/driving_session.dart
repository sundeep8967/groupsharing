import 'package:geolocator/geolocator.dart';

/// Model for a driving session - Life360 style
class DrivingSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final Position? startLocation;
  final Position? endLocation;
  final List<Position> route;
  final double? distance; // in meters
  final double? maxSpeed; // in m/s
  final double? averageSpeed; // in m/s
  final Duration? duration;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const DrivingSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.startLocation,
    this.endLocation,
    this.route = const [],
    this.distance,
    this.maxSpeed,
    this.averageSpeed,
    this.duration,
    required this.isActive,
    this.metadata,
  });

  /// Create a copy with updated fields
  DrivingSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    Position? startLocation,
    Position? endLocation,
    List<Position>? route,
    double? distance,
    double? maxSpeed,
    double? averageSpeed,
    Duration? duration,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return DrivingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      route: route ?? this.route,
      distance: distance ?? this.distance,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'startLocation': startLocation != null ? {
        'latitude': startLocation!.latitude,
        'longitude': startLocation!.longitude,
        'timestamp': startLocation!.timestamp.millisecondsSinceEpoch,
      } : null,
      'endLocation': endLocation != null ? {
        'latitude': endLocation!.latitude,
        'longitude': endLocation!.longitude,
        'timestamp': endLocation!.timestamp.millisecondsSinceEpoch,
      } : null,
      'route': route.map((pos) => {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': pos.timestamp.millisecondsSinceEpoch,
        'speed': pos.speed,
      }).toList(),
      'distance': distance,
      'maxSpeed': maxSpeed,
      'averageSpeed': averageSpeed,
      'duration': duration?.inMilliseconds,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Create from map (Firestore)
  factory DrivingSession.fromMap(Map<String, dynamic> map) {
    return DrivingSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] ?? 0),
      endTime: map['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      startLocation: map['startLocation'] != null 
          ? Position(
              latitude: map['startLocation']['latitude'],
              longitude: map['startLocation']['longitude'],
              timestamp: map['startLocation']['timestamp'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(map['startLocation']['timestamp'])
                  : DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            )
          : null,
      endLocation: map['endLocation'] != null 
          ? Position(
              latitude: map['endLocation']['latitude'],
              longitude: map['endLocation']['longitude'],
              timestamp: map['endLocation']['timestamp'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(map['endLocation']['timestamp'])
                  : DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            )
          : null,
      route: (map['route'] as List<dynamic>?)?.map((pos) => Position(
        latitude: pos['latitude'],
        longitude: pos['longitude'],
        timestamp: pos['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(pos['timestamp'])
            : DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: pos['speed']?.toDouble() ?? 0,
        speedAccuracy: 0,
      )).toList() ?? [],
      distance: map['distance']?.toDouble(),
      maxSpeed: map['maxSpeed']?.toDouble(),
      averageSpeed: map['averageSpeed']?.toDouble(),
      duration: map['duration'] != null 
          ? Duration(milliseconds: map['duration'])
          : null,
      isActive: map['isActive'] ?? false,
      metadata: map['metadata'],
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    if (duration == null) return 'Unknown';
    
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distance == null) return 'Unknown';
    
    if (distance! < 1000) {
      return '${distance!.round()}m';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Get formatted max speed string
  String get formattedMaxSpeed {
    if (maxSpeed == null) return 'Unknown';
    
    final kmh = maxSpeed! * 3.6;
    return '${kmh.round()} km/h';
  }

  /// Get formatted average speed string
  String get formattedAverageSpeed {
    if (averageSpeed == null) return 'Unknown';
    
    final kmh = averageSpeed! * 3.6;
    return '${kmh.round()} km/h';
  }

  /// Get driving score based on events and behavior
  int get drivingScore {
    // Basic scoring algorithm (can be enhanced)
    int score = 100;
    
    // Deduct points for high speeds
    if (maxSpeed != null && maxSpeed! > 25) { // > 90 km/h
      score -= 10;
    }
    
    // Add more scoring logic based on events
    // This would be enhanced with actual driving events data
    
    return score.clamp(0, 100);
  }

  @override
  String toString() {
    return 'DrivingSession(id: $id, userId: $userId, startTime: $startTime, '
           'endTime: $endTime, distance: $formattedDistance, '
           'maxSpeed: $formattedMaxSpeed, duration: $formattedDuration, '
           'isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is DrivingSession &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode;
  }
}