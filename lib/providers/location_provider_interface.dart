import 'package:latlong2/latlong.dart';

/// Common interface for all location providers.
///
/// This allows the app to standardize on one canonical provider while
/// keeping legacy providers compile-safe and swappable behind a single API.
abstract class ILocationProvider {
  // Lifecycle
  Future<bool> initialize();

  // State
  bool get isInitialized;
  bool get isTracking;
  String get status;
  String? get error;

  // Location data
  LatLng? get currentLocation;
  Map<String, LatLng> get userLocations;
  bool isUserSharingLocation(String userId);

  // Controls
  Future<bool> startTracking(String userId);
  Future<bool> stopTracking();
  Future<void> getCurrentLocationForMap();

  // Address (optional)
  String? get currentAddress;
  String? get city;
  String? get country;
  String? get postalCode;

  // Nearby users (optional)
  List<String> get nearbyUsers;
}


