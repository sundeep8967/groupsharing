import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:groupsharing/models/map_marker.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/location_service.dart';

/// A drop-in replacement for [AppMapWidget] that adds a "modern" UI layer
/// similar to Google / Uber / WhatsApp maps while remaining **100 % free** by
/// using open-source OpenStreetMap vector styles from Carto.
///
/// Features
/// ────────────────────────────────────────────────────────────────────────────
/// • Light & Dark map styles (CartoDB Positron / DarkMatter)
/// • Rounded-corner map with subtle shadow (Material 3)
/// • Floating zoom-in / zoom-out buttons
/// • "Locate me" button (centres camera on the user position)
/// • Optional search bar placeholder (for future geocoding integration)
/// • Elegant marker icons & clustering-ready (just swap the `MarkerLayer`)
class ModernMap extends StatefulWidget {
  final latlong.LatLng initialPosition;
  final Set<MapMarker> markers;
  final bool showUserLocation;
  final latlong.LatLng? userLocation;
  final void Function(MapMarker)? onMarkerTap;

  const ModernMap({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.userLocation,
    this.onMarkerTap,
  });

  @override
  State<ModernMap> createState() => _ModernMapState();
}

enum _MapTheme { light, dark }

class _ModernMapState extends State<ModernMap>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  MapController get _mapController => _animatedMapController.mapController;
  _MapTheme _currentTheme = _MapTheme.light;
  double? _heading;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  bool _hasMagnetometer = false;

  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  bool _isTracking = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startMagnetometer();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationTracking();
    });
  }
  

  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLocationTracking();
    } else if (state == AppLifecycleState.paused) {
      _stopLocationTracking();
    }
  }
  
  // Throttle location updates to prevent excessive rebuilds
  DateTime _lastUpdateTime = DateTime.now();
  latlong.LatLng? _lastPosition;
  
  // Calculate distance between two LatLng points in meters
  double _calculateDistance(latlong.LatLng pos1, latlong.LatLng pos2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(pos2.latitude - pos1.latitude);
    final double dLng = _toRadians(pos2.longitude - pos1.longitude);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(pos1.latitude)) * cos(_toRadians(pos2.latitude)) *
        sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  double _toRadians(double degree) {
    return degree * pi / 180;
  }
  
  Future<void> _startLocationTracking() async {
    if (_isTracking) return;
    
    try {
      final user = Provider.of<app_auth.AuthProvider>(context, listen: false).user;
      if (user == null) return;
      
      // Request location permission first
      final permission = await _locationService.requestLocationPermission();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        throw Exception('Location permission not granted');
      }
      
      // Enable background location if needed
      await _locationService.enableBackgroundLocation(enable: true);
      
      // Start tracking with throttled updates
      _locationSubscription = await _locationService.startTracking(
        user.uid,
        (latLng) {
          if (!mounted || !widget.showUserLocation) return;
          
          final now = DateTime.now();
          final newPosition = latlong.LatLng(latLng.latitude, latLng.longitude);
          
          // Only update if significant movement or enough time has passed
          if (_lastPosition == null ||
              _calculateDistance(_lastPosition!, newPosition) > 5.0 || // 5 meters
              now.difference(_lastUpdateTime) > const Duration(seconds: 5)) {
                
            _lastPosition = newPosition;
            _lastUpdateTime = now;
            
            // Animate the map movement smoothly
            _animatedMove(newPosition, _mapController.camera.zoom);
          }
        },
      );
      _isTracking = true;
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      // Handle error (e.g., show a snackbar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access location: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _stopLocationTracking() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _locationSubscription?.cancel();
    _animatedMapController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startMagnetometer() {
    try {
      _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
        if (mounted) {
          setState(() {
            // Calculate heading from magnetometer data
            final newHeading = (atan2(event.y, event.x) * 180 / pi) + 90;
            _heading = newHeading < 0 ? newHeading + 360 : newHeading;
            _hasMagnetometer = true;
          });
        }
      }, onError: (error) {
        // Handle error (e.g., no magnetometer available)
        debugPrint('Magnetometer error: $error');
        _hasMagnetometer = false;
      }, cancelOnError: true);
    } catch (e) {
      debugPrint('Error initializing magnetometer: $e');
      _hasMagnetometer = false;
    }
  }

  String get _tileUrl {
    switch (_currentTheme) {
      case _MapTheme.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
      case _MapTheme.light:
      default:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';
    }
  }

  // Cache manager for profile images
  static final _profileImageCache = DefaultCacheManager();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                onMapReady: () {
                  _isMapReady = true;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.groupsharing',
                  maxZoom: 19,
                  minZoom: 2,
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                ),
                MarkerLayer(
                  markers: [
                    // User location marker
                    if (widget.showUserLocation && widget.userLocation != null)
                      Marker(
                        width: 48,
                        height: 48,
                        point: widget.userLocation!,
                        child: Consumer<app_auth.AuthProvider>(
                          builder: (context, authProvider, _) {
                            final user = authProvider.user;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: user?.photoURL != null
                                    ? CachedNetworkImageProvider(
                                        user!.photoURL!,
                                        cacheKey: 'profile_${user.uid}',
                                        cacheManager: _profileImageCache,
                                        maxHeight: 200,
                                        maxWidth: 200,
                                      )
                                    : null,
                                child: user?.photoURL == null
                                    ? const Icon(Icons.person, size: 24)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    // Other markers
                    ...widget.markers.map(_toMarker),
                  ],
                ),
              ],
            ),
            // Search bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _SearchBar(onSubmitted: (q) {/* Hook up geocoding here */}),
            ),
            // Zoom controls
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  // Compass
                  if (_hasMagnetometer)
                    _CompassWidget(
                      heading: _heading ?? 0,
                      onTap: () {
                        // Reset map rotation to 0 (north up)
                        _mapController.rotate(0);
                      },
                    ),
                  const SizedBox(height: 8),
                  _CircleIconButton(
                    icon: Icons.add,
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _CircleIconButton(
                    icon: Icons.remove,
                    onTap: () => _zoomBy(-1),
                  ),
                  if (widget.showUserLocation) ...[
                    const SizedBox(height: 8),
                    _CircleIconButton(
                      icon: Icons.my_location,
                      onTap: _goToUserLocation,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _CircleIconButton(
                    icon: _currentTheme == _MapTheme.light ? Icons.dark_mode : Icons.light_mode,
                    onTap: _toggleTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to convert MapMarker to Marker widget.
  Marker _toMarker(MapMarker m) => Marker(
        width: 80,
        height: 80,
        point: m.point,
        child: GestureDetector(
          onTap: () => widget.onMarkerTap?.call(m),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      );

  void _zoomBy(double delta) {
    _animatedMove(_mapController.camera.center, _mapController.camera.zoom + delta);
  }

  void _goToUserLocation() {
    if (widget.userLocation == null) return;
    _animatedMove(widget.userLocation!, 17);
  }

  void _animatedMove(latlong.LatLng destLocation, double destZoom) async {
    if (!_isMapReady) {
      _mapController.move(destLocation, destZoom);
      return;
    }
    await _animatedMapController.animateTo(
      dest: destLocation,
      zoom: destZoom,
      curve: Curves.easeOut,
    );
  }

  void _toggleTheme() {
    setState(() {
      _currentTheme = _currentTheme == _MapTheme.light ? _MapTheme.dark : _MapTheme.light;
    });
  }
}

/// Search bar placeholder. Replace with real geocoding if desired.
class _SearchBar extends StatelessWidget {
  final void Function(String) onSubmitted;
  const _SearchBar({required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search place…',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// A custom Tween for animating [LatLng] coordinates.
class LatLngTween extends Tween<latlong.LatLng> {
  LatLngTween({required latlong.LatLng begin, required latlong.LatLng end})
      : super(begin: begin, end: end);

  @override
  latlong.LatLng lerp(double t) {
    return latlong.LatLng(
      lerpDouble(begin!.latitude, end!.latitude, t)!,
      lerpDouble(begin!.longitude, end!.longitude, t)!,
    );
  }
}

/// A compass widget that shows the current device heading
class _CompassWidget extends StatelessWidget {
  final double heading;
  final VoidCallback onTap;

  const _CompassWidget({
    required this.heading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: heading * (pi / 180) * -1,
              child: Icon(
                Icons.navigation,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            Center(
              child: Text(
                _getCompassDirection(heading),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCompassDirection(double heading) {
    // Convert heading to compass direction (0-360)
    double compass = (360 - heading) % 360;
    
    // Define directions
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    
    // Calculate index (0-7 for the 8 directions)
    int index = ((compass + 22.5) / 45.0).floor() % 8;
    
    return directions[index];
  }
}

/// A round Material button used for map controls.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
