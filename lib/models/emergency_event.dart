import 'package:geolocator/geolocator.dart';

/// Emergency event model for Life360-style emergency tracking
class EmergencyEvent {
  final String id;
  final String userId;
  final EmergencyType type;
  final String? message;
  final Position? location;
  final DateTime timestamp;
  final DateTime? resolvedAt;
  final String? resolution;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const EmergencyEvent({
    required this.id,
    required this.userId,
    required this.type,
    this.message,
    this.location,
    required this.timestamp,
    this.resolvedAt,
    this.resolution,
    required this.isActive,
    this.metadata,
  });

  /// Create a copy with updated fields
  EmergencyEvent copyWith({
    String? id,
    String? userId,
    EmergencyType? type,
    String? message,
    Position? location,
    DateTime? timestamp,
    DateTime? resolvedAt,
    String? resolution,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return EmergencyEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      message: message ?? this.message,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString(),
      'message': message,
      'location': location != null ? {
        'latitude': location!.latitude,
        'longitude': location!.longitude,
        'timestamp': location!.timestamp.millisecondsSinceEpoch,
        'accuracy': location!.accuracy,
      } : null,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      'resolution': resolution,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Create from map (Firestore)
  factory EmergencyEvent.fromMap(Map<String, dynamic> map) {
    return EmergencyEvent(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: EmergencyType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => EmergencyType.general,
      ),
      message: map['message'],
      location: map['location'] != null 
          ? Position(
              latitude: map['location']['latitude'],
              longitude: map['location']['longitude'],
              timestamp: map['location']['timestamp'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(map['location']['timestamp'])
                  : DateTime.now(),
              accuracy: map['location']['accuracy']?.toDouble() ?? 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            )
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      resolvedAt: map['resolvedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['resolvedAt'])
          : null,
      resolution: map['resolution'],
      isActive: map['isActive'] ?? false,
      metadata: map['metadata'],
    );
  }

  /// Get emergency type icon
  String get typeIcon {
    switch (type) {
      case EmergencyType.medical:
        return '🚑';
      case EmergencyType.accident:
        return '🚗';
      case EmergencyType.crime:
        return '🚨';
      case EmergencyType.fire:
        return '🔥';
      case EmergencyType.natural:
        return '⛈️';
      case EmergencyType.general:
        return '🆘';
    }
  }

  /// Get emergency type display name
  String get typeDisplayName {
    switch (type) {
      case EmergencyType.medical:
        return 'Medical Emergency';
      case EmergencyType.accident:
        return 'Accident';
      case EmergencyType.crime:
        return 'Crime/Safety';
      case EmergencyType.fire:
        return 'Fire';
      case EmergencyType.natural:
        return 'Natural Disaster';
      case EmergencyType.general:
        return 'General Emergency';
    }
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
           '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Get formatted duration
  String get formattedDuration {
    final endTime = resolvedAt ?? DateTime.now();
    final duration = endTime.difference(timestamp);
    
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
  }

  /// Get location string
  String get locationString {
    if (location == null) return 'Location not available';
    
    return '${location!.latitude.toStringAsFixed(6)}, '
           '${location!.longitude.toStringAsFixed(6)}';
  }

  /// Get Google Maps URL
  String get googleMapsUrl {
    if (location == null) return '';
    
    return 'https://www.google.com/maps/search/?api=1&query='
           '${location!.latitude},${location!.longitude}';
  }

  /// Get status description
  String get statusDescription {
    if (isActive) {
      return 'Active Emergency';
    } else if (resolvedAt != null) {
      return 'Resolved';
    } else {
      return 'Unknown Status';
    }
  }

  @override
  String toString() {
    return 'EmergencyEvent(id: $id, userId: $userId, type: $typeDisplayName, '
           'timestamp: $formattedTimestamp, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is EmergencyEvent &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode;
  }
}

/// Enum for emergency types
enum EmergencyType {
  medical,
  accident,
  crime,
  fire,
  natural,
  general,
}

/// Extension to add displayName getter to EmergencyType
extension EmergencyTypeExtension on EmergencyType {
  String get displayName {
    switch (this) {
      case EmergencyType.medical:
        return 'Medical Emergency';
      case EmergencyType.accident:
        return 'Accident';
      case EmergencyType.crime:
        return 'Crime/Safety';
      case EmergencyType.fire:
        return 'Fire';
      case EmergencyType.natural:
        return 'Natural Disaster';
      case EmergencyType.general:
        return 'General Emergency';
    }
  }
}