import 'package:latlong2/latlong.dart';

/// Advanced geofence model with enhanced features
class AdvancedGeofence {
  final String id;
  final String userId;
  final String name;
  final String description;
  final GeofenceShape shape;
  final List<LatLng> coordinates; // For polygon geofences
  final double radius; // For circular geofences
  final GeofenceType type;
  final GeofencePriority priority;
  final bool isActive;
  final bool isShared;
  final List<String> sharedWithUsers;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final GeofenceSchedule? schedule;
  final GeofenceConditions conditions;
  final GeofenceActions actions;
  final GeofenceAnalytics analytics;
  final Map<String, dynamic>? metadata;

  const AdvancedGeofence({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    required this.shape,
    required this.coordinates,
    this.radius = 100.0,
    this.type = GeofenceType.standard,
    this.priority = GeofencePriority.normal,
    this.isActive = true,
    this.isShared = false,
    this.sharedWithUsers = const [],
    required this.createdAt,
    this.expiresAt,
    this.schedule,
    required this.conditions,
    required this.actions,
    required this.analytics,
    this.metadata,
  });

  /// Create a circular geofence
  factory AdvancedGeofence.circular({
    required String id,
    required String userId,
    required String name,
    required LatLng center,
    required double radius,
    GeofenceType type = GeofenceType.standard,
    GeofencePriority priority = GeofencePriority.normal,
    String description = '',
    GeofenceSchedule? schedule,
    GeofenceConditions? conditions,
    GeofenceActions? actions,
  }) {
    return AdvancedGeofence(
      id: id,
      userId: userId,
      name: name,
      description: description,
      shape: GeofenceShape.circle,
      coordinates: [center],
      radius: radius,
      type: type,
      priority: priority,
      createdAt: DateTime.now(),
      schedule: schedule,
      conditions: conditions ?? GeofenceConditions.standard(),
      actions: actions ?? GeofenceActions.standard(),
      analytics: GeofenceAnalytics.empty(),
    );
  }

  /// Create a polygon geofence
  factory AdvancedGeofence.polygon({
    required String id,
    required String userId,
    required String name,
    required List<LatLng> vertices,
    GeofenceType type = GeofenceType.standard,
    GeofencePriority priority = GeofencePriority.normal,
    String description = '',
    GeofenceSchedule? schedule,
    GeofenceConditions? conditions,
    GeofenceActions? actions,
  }) {
    return AdvancedGeofence(
      id: id,
      userId: userId,
      name: name,
      description: description,
      shape: GeofenceShape.polygon,
      coordinates: vertices,
      radius: 0.0,
      type: type,
      priority: priority,
      createdAt: DateTime.now(),
      schedule: schedule,
      conditions: conditions ?? GeofenceConditions.standard(),
      actions: actions ?? GeofenceActions.standard(),
      analytics: GeofenceAnalytics.empty(),
    );
  }

  /// Create a rectangular geofence
  factory AdvancedGeofence.rectangle({
    required String id,
    required String userId,
    required String name,
    required LatLng northEast,
    required LatLng southWest,
    GeofenceType type = GeofenceType.standard,
    GeofencePriority priority = GeofencePriority.normal,
    String description = '',
    GeofenceSchedule? schedule,
    GeofenceConditions? conditions,
    GeofenceActions? actions,
  }) {
    final vertices = [
      northEast,
      LatLng(southWest.latitude, northEast.longitude),
      southWest,
      LatLng(northEast.latitude, southWest.longitude),
    ];

    return AdvancedGeofence.polygon(
      id: id,
      userId: userId,
      name: name,
      vertices: vertices,
      type: type,
      priority: priority,
      description: description,
      schedule: schedule,
      conditions: conditions,
      actions: actions,
    );
  }

  /// Get the center point of the geofence
  LatLng get center {
    if (shape == GeofenceShape.circle) {
      return coordinates.first;
    }
    
    // Calculate centroid for polygon
    double lat = 0;
    double lng = 0;
    for (final coord in coordinates) {
      lat += coord.latitude;
      lng += coord.longitude;
    }
    return LatLng(lat / coordinates.length, lng / coordinates.length);
  }

  /// Check if a point is inside this geofence
  bool containsPoint(LatLng point) {
    switch (shape) {
      case GeofenceShape.circle:
        final distance = Distance().as(LengthUnit.Meter, center, point);
        return distance <= radius;
      
      case GeofenceShape.polygon:
      case GeofenceShape.rectangle:
        return _pointInPolygon(point, coordinates);
    }
  }

  /// Point-in-polygon algorithm
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;
      
      if (((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  /// Check if geofence is currently active based on schedule and conditions
  bool get isCurrentlyActive {
    if (!isActive) return false;
    
    final now = DateTime.now();
    
    // Check expiration
    if (expiresAt != null && now.isAfter(expiresAt!)) {
      return false;
    }
    
    // Check schedule
    if (schedule != null && !schedule!.isActiveAt(now)) {
      return false;
    }
    
    return true;
  }

  /// Get geofence area in square meters
  double get area {
    switch (shape) {
      case GeofenceShape.circle:
        return 3.14159 * radius * radius;
      
      case GeofenceShape.polygon:
      case GeofenceShape.rectangle:
        return _calculatePolygonArea();
    }
  }

  /// Calculate polygon area using shoelace formula
  double _calculatePolygonArea() {
    if (coordinates.length < 3) return 0;
    
    double area = 0;
    int j = coordinates.length - 1;
    
    for (int i = 0; i < coordinates.length; i++) {
      area += (coordinates[j].longitude + coordinates[i].longitude) * 
              (coordinates[j].latitude - coordinates[i].latitude);
      j = i;
    }
    
    return (area.abs() / 2) * 111320 * 111320; // Convert to square meters
  }

  /// Copy with updated fields
  AdvancedGeofence copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    GeofenceShape? shape,
    List<LatLng>? coordinates,
    double? radius,
    GeofenceType? type,
    GeofencePriority? priority,
    bool? isActive,
    bool? isShared,
    List<String>? sharedWithUsers,
    DateTime? createdAt,
    DateTime? expiresAt,
    GeofenceSchedule? schedule,
    GeofenceConditions? conditions,
    GeofenceActions? actions,
    GeofenceAnalytics? analytics,
    Map<String, dynamic>? metadata,
  }) {
    return AdvancedGeofence(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      shape: shape ?? this.shape,
      coordinates: coordinates ?? this.coordinates,
      radius: radius ?? this.radius,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      isShared: isShared ?? this.isShared,
      sharedWithUsers: sharedWithUsers ?? this.sharedWithUsers,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      schedule: schedule ?? this.schedule,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      analytics: analytics ?? this.analytics,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'shape': shape.name,
      'coordinates': coordinates.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
      'radius': radius,
      'type': type.name,
      'priority': priority.name,
      'isActive': isActive,
      'isShared': isShared,
      'sharedWithUsers': sharedWithUsers,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'schedule': schedule?.toMap(),
      'conditions': conditions.toMap(),
      'actions': actions.toMap(),
      'analytics': analytics.toMap(),
      'metadata': metadata,
    };
  }

  /// Create from map
  factory AdvancedGeofence.fromMap(Map<String, dynamic> map) {
    return AdvancedGeofence(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      shape: GeofenceShape.values.firstWhere(
        (e) => e.name == map['shape'],
        orElse: () => GeofenceShape.circle,
      ),
      coordinates: (map['coordinates'] as List<dynamic>?)
          ?.map((c) => LatLng(c['lat']?.toDouble() ?? 0.0, c['lng']?.toDouble() ?? 0.0))
          .toList() ?? [],
      radius: map['radius']?.toDouble() ?? 100.0,
      type: GeofenceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GeofenceType.standard,
      ),
      priority: GeofencePriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => GeofencePriority.normal,
      ),
      isActive: map['isActive'] ?? true,
      isShared: map['isShared'] ?? false,
      sharedWithUsers: List<String>.from(map['sharedWithUsers'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      expiresAt: map['expiresAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : null,
      schedule: map['schedule'] != null 
          ? GeofenceSchedule.fromMap(map['schedule'])
          : null,
      conditions: GeofenceConditions.fromMap(map['conditions'] ?? {}),
      actions: GeofenceActions.fromMap(map['actions'] ?? {}),
      analytics: GeofenceAnalytics.fromMap(map['analytics'] ?? {}),
      metadata: map['metadata'],
    );
  }

  @override
  String toString() {
    return 'AdvancedGeofence(id: $id, name: $name, shape: $shape, type: $type, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdvancedGeofence && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Geofence shape types
enum GeofenceShape {
  circle,
  polygon,
  rectangle,
}

/// Geofence types for different use cases
enum GeofenceType {
  standard,      // Regular geofence
  safe,          // Safe zone (home, school)
  restricted,    // Restricted area
  emergency,     // Emergency zone
  temporary,     // Temporary geofence
  smart,         // AI-optimized geofence
}

/// Geofence priority levels
enum GeofencePriority {
  low,
  normal,
  high,
  critical,
}

/// Geofence schedule for time-based activation
class GeofenceSchedule {
  final bool isEnabled;
  final List<DayOfWeek> activeDays;
  final TimeRange? activeTimeRange;
  final List<TimeRange> customTimeRanges;
  final String timezone;

  const GeofenceSchedule({
    this.isEnabled = true,
    this.activeDays = const [],
    this.activeTimeRange,
    this.customTimeRanges = const [],
    this.timezone = 'UTC',
  });

  /// Check if schedule is active at given time
  bool isActiveAt(DateTime dateTime) {
    if (!isEnabled) return true;
    
    // Check day of week
    if (activeDays.isNotEmpty) {
      final dayOfWeek = DayOfWeek.values[dateTime.weekday - 1];
      if (!activeDays.contains(dayOfWeek)) return false;
    }
    
    // Check time range
    final timeOfDay = TimeOfDay(dateTime.hour, dateTime.minute);
    
    if (activeTimeRange != null) {
      return activeTimeRange!.contains(timeOfDay);
    }
    
    if (customTimeRanges.isNotEmpty) {
      return customTimeRanges.any((range) => range.contains(timeOfDay));
    }
    
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'activeDays': activeDays.map((d) => d.name).toList(),
      'activeTimeRange': activeTimeRange?.toMap(),
      'customTimeRanges': customTimeRanges.map((r) => r.toMap()).toList(),
      'timezone': timezone,
    };
  }

  factory GeofenceSchedule.fromMap(Map<String, dynamic> map) {
    return GeofenceSchedule(
      isEnabled: map['isEnabled'] ?? true,
      activeDays: (map['activeDays'] as List<dynamic>?)
          ?.map((d) => DayOfWeek.values.firstWhere((e) => e.name == d))
          .toList() ?? [],
      activeTimeRange: map['activeTimeRange'] != null 
          ? TimeRange.fromMap(map['activeTimeRange'])
          : null,
      customTimeRanges: (map['customTimeRanges'] as List<dynamic>?)
          ?.map((r) => TimeRange.fromMap(r))
          .toList() ?? [],
      timezone: map['timezone'] ?? 'UTC',
    );
  }
}

/// Days of the week
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

/// Time range for scheduling
class TimeRange {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeRange(this.start, this.end);

  bool contains(TimeOfDay time) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final timeMinutes = time.hour * 60 + time.minute;
    
    if (startMinutes <= endMinutes) {
      // Same day range
      return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
    } else {
      // Overnight range
      return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'start': {'hour': start.hour, 'minute': start.minute},
      'end': {'hour': end.hour, 'minute': end.minute},
    };
  }

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    final startMap = map['start'] as Map<String, dynamic>;
    final endMap = map['end'] as Map<String, dynamic>;
    
    return TimeRange(
      TimeOfDay(startMap['hour'] ?? 0, startMap['minute'] ?? 0),
      TimeOfDay(endMap['hour'] ?? 23, endMap['minute'] ?? 59),
    );
  }
}

/// Time of day helper class
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay(this.hour, this.minute);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Geofence conditions for advanced triggering
class GeofenceConditions {
  final double minimumDwellTime; // seconds
  final double minimumSpeed; // m/s
  final double maximumSpeed; // m/s
  final List<String> requiredDevices;
  final WeatherConditions? weatherConditions;
  final BatteryConditions? batteryConditions;
  final bool requiresConfirmation;

  const GeofenceConditions({
    this.minimumDwellTime = 0,
    this.minimumSpeed = 0,
    this.maximumSpeed = double.infinity,
    this.requiredDevices = const [],
    this.weatherConditions,
    this.batteryConditions,
    this.requiresConfirmation = false,
  });

  factory GeofenceConditions.standard() {
    return const GeofenceConditions();
  }

  Map<String, dynamic> toMap() {
    return {
      'minimumDwellTime': minimumDwellTime,
      'minimumSpeed': minimumSpeed,
      'maximumSpeed': maximumSpeed,
      'requiredDevices': requiredDevices,
      'weatherConditions': weatherConditions?.toMap(),
      'batteryConditions': batteryConditions?.toMap(),
      'requiresConfirmation': requiresConfirmation,
    };
  }

  factory GeofenceConditions.fromMap(Map<String, dynamic> map) {
    return GeofenceConditions(
      minimumDwellTime: map['minimumDwellTime']?.toDouble() ?? 0,
      minimumSpeed: map['minimumSpeed']?.toDouble() ?? 0,
      maximumSpeed: map['maximumSpeed']?.toDouble() ?? double.infinity,
      requiredDevices: List<String>.from(map['requiredDevices'] ?? []),
      weatherConditions: map['weatherConditions'] != null 
          ? WeatherConditions.fromMap(map['weatherConditions'])
          : null,
      batteryConditions: map['batteryConditions'] != null 
          ? BatteryConditions.fromMap(map['batteryConditions'])
          : null,
      requiresConfirmation: map['requiresConfirmation'] ?? false,
    );
  }
}

/// Weather-based conditions
class WeatherConditions {
  final List<String> allowedWeatherTypes;
  final double? minimumTemperature;
  final double? maximumTemperature;

  const WeatherConditions({
    this.allowedWeatherTypes = const [],
    this.minimumTemperature,
    this.maximumTemperature,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowedWeatherTypes': allowedWeatherTypes,
      'minimumTemperature': minimumTemperature,
      'maximumTemperature': maximumTemperature,
    };
  }

  factory WeatherConditions.fromMap(Map<String, dynamic> map) {
    return WeatherConditions(
      allowedWeatherTypes: List<String>.from(map['allowedWeatherTypes'] ?? []),
      minimumTemperature: map['minimumTemperature']?.toDouble(),
      maximumTemperature: map['maximumTemperature']?.toDouble(),
    );
  }
}

/// Battery-based conditions
class BatteryConditions {
  final double? minimumBatteryLevel;
  final bool requiresCharging;

  const BatteryConditions({
    this.minimumBatteryLevel,
    this.requiresCharging = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'minimumBatteryLevel': minimumBatteryLevel,
      'requiresCharging': requiresCharging,
    };
  }

  factory BatteryConditions.fromMap(Map<String, dynamic> map) {
    return BatteryConditions(
      minimumBatteryLevel: map['minimumBatteryLevel']?.toDouble(),
      requiresCharging: map['requiresCharging'] ?? false,
    );
  }
}

/// Geofence actions to execute on trigger
class GeofenceActions {
  final bool sendNotification;
  final bool sendEmail;
  final bool sendSms;
  final List<String> notifyUsers;
  final String? customMessage;
  final List<AutomationAction> automationActions;
  final bool logEvent;
  final bool updateUserStatus;

  const GeofenceActions({
    this.sendNotification = true,
    this.sendEmail = false,
    this.sendSms = false,
    this.notifyUsers = const [],
    this.customMessage,
    this.automationActions = const [],
    this.logEvent = true,
    this.updateUserStatus = true,
  });

  factory GeofenceActions.standard() {
    return const GeofenceActions();
  }

  Map<String, dynamic> toMap() {
    return {
      'sendNotification': sendNotification,
      'sendEmail': sendEmail,
      'sendSms': sendSms,
      'notifyUsers': notifyUsers,
      'customMessage': customMessage,
      'automationActions': automationActions.map((a) => a.toMap()).toList(),
      'logEvent': logEvent,
      'updateUserStatus': updateUserStatus,
    };
  }

  factory GeofenceActions.fromMap(Map<String, dynamic> map) {
    return GeofenceActions(
      sendNotification: map['sendNotification'] ?? true,
      sendEmail: map['sendEmail'] ?? false,
      sendSms: map['sendSms'] ?? false,
      notifyUsers: List<String>.from(map['notifyUsers'] ?? []),
      customMessage: map['customMessage'],
      automationActions: (map['automationActions'] as List<dynamic>?)
          ?.map((a) => AutomationAction.fromMap(a))
          .toList() ?? [],
      logEvent: map['logEvent'] ?? true,
      updateUserStatus: map['updateUserStatus'] ?? true,
    );
  }
}

/// Automation action for geofence triggers
class AutomationAction {
  final String type;
  final Map<String, dynamic> parameters;

  const AutomationAction({
    required this.type,
    this.parameters = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'parameters': parameters,
    };
  }

  factory AutomationAction.fromMap(Map<String, dynamic> map) {
    return AutomationAction(
      type: map['type'] ?? '',
      parameters: Map<String, dynamic>.from(map['parameters'] ?? {}),
    );
  }
}

/// Geofence analytics and statistics
class GeofenceAnalytics {
  final int totalTriggers;
  final int enterEvents;
  final int exitEvents;
  final int dwellEvents;
  final DateTime? lastTriggered;
  final double averageDwellTime;
  final double totalDwellTime;
  final List<GeofenceEvent> recentEvents;

  const GeofenceAnalytics({
    this.totalTriggers = 0,
    this.enterEvents = 0,
    this.exitEvents = 0,
    this.dwellEvents = 0,
    this.lastTriggered,
    this.averageDwellTime = 0,
    this.totalDwellTime = 0,
    this.recentEvents = const [],
  });

  factory GeofenceAnalytics.empty() {
    return const GeofenceAnalytics();
  }

  Map<String, dynamic> toMap() {
    return {
      'totalTriggers': totalTriggers,
      'enterEvents': enterEvents,
      'exitEvents': exitEvents,
      'dwellEvents': dwellEvents,
      'lastTriggered': lastTriggered?.millisecondsSinceEpoch,
      'averageDwellTime': averageDwellTime,
      'totalDwellTime': totalDwellTime,
      'recentEvents': recentEvents.map((e) => e.toMap()).toList(),
    };
  }

  factory GeofenceAnalytics.fromMap(Map<String, dynamic> map) {
    return GeofenceAnalytics(
      totalTriggers: map['totalTriggers'] ?? 0,
      enterEvents: map['enterEvents'] ?? 0,
      exitEvents: map['exitEvents'] ?? 0,
      dwellEvents: map['dwellEvents'] ?? 0,
      lastTriggered: map['lastTriggered'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastTriggered'])
          : null,
      averageDwellTime: map['averageDwellTime']?.toDouble() ?? 0,
      totalDwellTime: map['totalDwellTime']?.toDouble() ?? 0,
      recentEvents: (map['recentEvents'] as List<dynamic>?)
          ?.map((e) => GeofenceEvent.fromMap(e))
          .toList() ?? [],
    );
  }
}

/// Geofence event for analytics
class GeofenceEvent {
  final String id;
  final String geofenceId;
  final String userId;
  final GeofenceEventType type;
  final DateTime timestamp;
  final LatLng? location;
  final double? accuracy;
  final Map<String, dynamic>? metadata;

  const GeofenceEvent({
    required this.id,
    required this.geofenceId,
    required this.userId,
    required this.type,
    required this.timestamp,
    this.location,
    this.accuracy,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'geofenceId': geofenceId,
      'userId': userId,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'location': location != null 
          ? {'lat': location!.latitude, 'lng': location!.longitude}
          : null,
      'accuracy': accuracy,
      'metadata': metadata,
    };
  }

  factory GeofenceEvent.fromMap(Map<String, dynamic> map) {
    return GeofenceEvent(
      id: map['id'] ?? '',
      geofenceId: map['geofenceId'] ?? '',
      userId: map['userId'] ?? '',
      type: GeofenceEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GeofenceEventType.enter,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      location: map['location'] != null 
          ? LatLng(map['location']['lat']?.toDouble() ?? 0.0, 
                   map['location']['lng']?.toDouble() ?? 0.0)
          : null,
      accuracy: map['accuracy']?.toDouble(),
      metadata: map['metadata'],
    );
  }
}

/// Geofence event types
enum GeofenceEventType {
  enter,
  exit,
  dwell,
}