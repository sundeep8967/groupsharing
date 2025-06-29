/// Smart place model for Life360-style geofencing and place detection
class SmartPlace {
  final String id;
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // in meters
  final PlaceType type;
  final bool notificationsEnabled;
  final bool automationEnabled;
  final bool isAutoDetected;
  final DateTime createdAt;
  final DateTime? lastVisit;
  final DateTime? lastDeparture;
  final int visitCount;
  final bool isUserInside;
  final Map<String, dynamic>? metadata;

  const SmartPlace({
    required this.id,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 100.0,
    this.type = PlaceType.other,
    this.notificationsEnabled = true,
    this.automationEnabled = false,
    this.isAutoDetected = false,
    required this.createdAt,
    this.lastVisit,
    this.lastDeparture,
    this.visitCount = 0,
    this.isUserInside = false,
    this.metadata,
  });

  /// Create a copy with updated fields
  SmartPlace copyWith({
    String? id,
    String? userId,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    PlaceType? type,
    bool? notificationsEnabled,
    bool? automationEnabled,
    bool? isAutoDetected,
    DateTime? createdAt,
    DateTime? lastVisit,
    DateTime? lastDeparture,
    int? visitCount,
    bool? isUserInside,
    Map<String, dynamic>? metadata,
  }) {
    return SmartPlace(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      automationEnabled: automationEnabled ?? this.automationEnabled,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      createdAt: createdAt ?? this.createdAt,
      lastVisit: lastVisit ?? this.lastVisit,
      lastDeparture: lastDeparture ?? this.lastDeparture,
      visitCount: visitCount ?? this.visitCount,
      isUserInside: isUserInside ?? this.isUserInside,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'type': type.toString(),
      'notificationsEnabled': notificationsEnabled,
      'automationEnabled': automationEnabled,
      'isAutoDetected': isAutoDetected,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastVisit': lastVisit?.millisecondsSinceEpoch,
      'lastDeparture': lastDeparture?.millisecondsSinceEpoch,
      'visitCount': visitCount,
      'isUserInside': isUserInside,
      'metadata': metadata,
    };
  }

  /// Create from map (Firestore)
  factory SmartPlace.fromMap(Map<String, dynamic> map) {
    return SmartPlace(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      radius: map['radius']?.toDouble() ?? 100.0,
      type: PlaceType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => PlaceType.other,
      ),
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      automationEnabled: map['automationEnabled'] ?? false,
      isAutoDetected: map['isAutoDetected'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      lastVisit: map['lastVisit'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastVisit'])
          : null,
      lastDeparture: map['lastDeparture'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastDeparture'])
          : null,
      visitCount: map['visitCount'] ?? 0,
      isUserInside: map['isUserInside'] ?? false,
      metadata: map['metadata'],
    );
  }

  /// Get place type icon
  String get typeIcon {
    switch (type) {
      case PlaceType.home:
        return '🏠';
      case PlaceType.work:
        return '🏢';
      case PlaceType.school:
        return '🏫';
      case PlaceType.gym:
        return '💪';
      case PlaceType.shopping:
        return '🛍️';
      case PlaceType.restaurant:
        return '🍽️';
      case PlaceType.hospital:
        return '🏥';
      case PlaceType.other:
        return '📍';
    }
  }

  /// Get place type display name
  String get typeDisplayName {
    switch (type) {
      case PlaceType.home:
        return 'Home';
      case PlaceType.work:
        return 'Work';
      case PlaceType.school:
        return 'School';
      case PlaceType.gym:
        return 'Gym';
      case PlaceType.shopping:
        return 'Shopping';
      case PlaceType.restaurant:
        return 'Restaurant';
      case PlaceType.hospital:
        return 'Hospital';
      case PlaceType.other:
        return 'Other';
    }
  }

  /// Get formatted radius string
  String get formattedRadius {
    if (radius < 1000) {
      return '${radius.round()}m';
    } else {
      return '${(radius / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Get last visit formatted string
  String get formattedLastVisit {
    if (lastVisit == null) return 'Never visited';
    
    final now = DateTime.now();
    final difference = now.difference(lastVisit!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Get visit frequency description
  String get visitFrequency {
    if (visitCount == 0) return 'Never visited';
    if (visitCount == 1) return 'Visited once';
    if (visitCount < 5) return 'Rarely visited';
    if (visitCount < 20) return 'Sometimes visited';
    if (visitCount < 50) return 'Often visited';
    return 'Frequently visited';
  }

  @override
  String toString() {
    return 'SmartPlace(id: $id, name: $name, type: $typeDisplayName, '
           'latitude: $latitude, longitude: $longitude, radius: $formattedRadius, '
           'visitCount: $visitCount, isUserInside: $isUserInside)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SmartPlace &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode;
  }
}

/// Enum for different place types
enum PlaceType {
  home,
  work,
  school,
  gym,
  shopping,
  restaurant,
  hospital,
  other,
}

/// Extension to add helper methods to PlaceType
extension PlaceTypeExtension on PlaceType {
  /// Get place type icon
  String get icon {
    switch (this) {
      case PlaceType.home:
        return '🏠';
      case PlaceType.work:
        return '🏢';
      case PlaceType.school:
        return '🏫';
      case PlaceType.gym:
        return '💪';
      case PlaceType.shopping:
        return '🛍️';
      case PlaceType.restaurant:
        return '🍽️';
      case PlaceType.hospital:
        return '🏥';
      case PlaceType.other:
        return '📍';
    }
  }

  /// Get place type display name
  String get displayName {
    switch (this) {
      case PlaceType.home:
        return 'Home';
      case PlaceType.work:
        return 'Work';
      case PlaceType.school:
        return 'School';
      case PlaceType.gym:
        return 'Gym';
      case PlaceType.shopping:
        return 'Shopping';
      case PlaceType.restaurant:
        return 'Restaurant';
      case PlaceType.hospital:
        return 'Hospital';
      case PlaceType.other:
        return 'Other';
    }
  }
}