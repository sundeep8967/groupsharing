import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as FMTC;
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:groupsharing/models/map_marker.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class _Debouncer {
  final Duration delay;
  Timer? _timer;

  _Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

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

  // Add these to prevent excessive rebuilds
  late List<Marker> _cachedMarkers;
  Set<MapMarker>? _lastMarkersSet;

  final _markerCache = <String, Marker>{}; // Marker cache for marker deduplication
  static final _profileImageCache = DefaultCacheManager();

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cachedMarkers = [];
    _startMagnetometer();
    WidgetsBinding.instance.addObserver(this);
    FMTC.FMTCStore('mainCache').manage.create();
  }

  @override
  void didUpdateWidget(ModernMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers) {
      _rebuildMarkerCache();
    }
  }

  void _rebuildMarkerCache() {
    _markerCache.clear();
    _lastMarkersSet = null;
    if (mounted) {
      setState(() {
        _cachedMarkers = _buildAllMarkers();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startMagnetometer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        _magnetometerSubscription?.cancel();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _magnetometerSubscription?.cancel();
    _animatedMapController.dispose();
    super.dispose();
  }

  void _startMagnetometer() {
    if (_hasMagnetometer) return; // Prevent multiple subscriptions
    
    try {
      _magnetometerSubscription?.cancel(); // Cancel existing subscription
      _magnetometerSubscription = magnetometerEvents.listen(
        (MagnetometerEvent event) {
          if (!mounted) return;
          
          final newHeading = (atan2(event.y, event.x) * 180 / pi) + 90;
          final normalizedHeading = newHeading < 0 ? newHeading + 360 : newHeading;
          
          // Only update if heading changed significantly (reduce noise)
          if (_heading == null || ((_heading! - normalizedHeading).abs() > 5)) {
            if (mounted) {
              setState(() {
                _heading = normalizedHeading;
                _hasMagnetometer = true;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Magnetometer error: $error');
          if (mounted) {
            setState(() {
              _hasMagnetometer = false;
            });
          }
        },
        cancelOnError: false, // Don't cancel on error, keep trying
      );
    } catch (e) {
      debugPrint('Error initializing magnetometer: $e');
      _hasMagnetometer = false;
    }
  }

  String get _tileUrl =>
      _currentTheme == _MapTheme.dark
          // CartoDB Dark Matter (blue water)
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
          // CartoDB Positron (light, blue water)
          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';

  List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];
    
    // Add user location marker
    if (widget.showUserLocation && widget.userLocation != null) {
      markers.add(
        Marker(
          width: 48,
          height: 48,
          point: widget.userLocation!,
          child: _UserLocationMarker(),
        ),
      );
    }
    
    // Add other markers with caching
    for (final mapMarker in widget.markers) {
      final cacheKey = '${mapMarker.point.latitude}_${mapMarker.point.longitude}_${mapMarker.hashCode}';
      final cachedMarker = _markerCache[cacheKey];
      
      if (cachedMarker != null) {
        markers.add(cachedMarker);
      } else {
        final newMarker = _buildMarker(mapMarker);
        _markerCache[cacheKey] = newMarker;
        markers.add(newMarker);
      }
    }
    
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild markers if they changed
    if (_lastMarkersSet != widget.markers) {
      _cachedMarkers = _buildAllMarkers();
      _lastMarkersSet = widget.markers;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('${_currentTheme}_${widget.initialPosition}'), // More stable key
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialPosition,
                initialZoom: 15,
                minZoom: 2,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | 
                         InteractiveFlag.drag |
                         InteractiveFlag.doubleTapZoom,
                ),
                onMapReady: () {
                  debugPrint('Map ready');
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
                  tileProvider: FMTC.FMTCStore('mainCache').getTileProvider(),
                  // Add error handling for tiles
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('Tile error: $error');
                  },
                ),
                MarkerLayer(
                  markers: _cachedMarkers,
                ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _SearchBar(onSubmitted: (q) {}),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasMagnetometer && _heading != null)
                    _CompassWidget(
                      heading: _heading!,
                      onTap: () {
                        if (mounted) {
                          _mapController.rotate(0);
                        }
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

  Marker _buildMarker(MapMarker m) {
    // Fetch user profile photo from Firestore (if available)
    return Marker(
      width: 48,
      height: 48,
      point: m.point,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(m.id).get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final photoUrl = data?['photoUrl'];
          final displayName = data?['displayName'] ?? '';
          if (photoUrl != null && photoUrl.isNotEmpty) {
            return AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: CachedNetworkImageProvider(photoUrl, cacheKey: 'profile_${m.id}'),
                  backgroundColor: Colors.white,
                ),
              ),
            );
          } else {
            // Fallback: colored initial
            return AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Colors.blueAccent,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _zoomBy(double delta) {
    if (mounted) {
      final newZoom = (_mapController.camera.zoom + delta).clamp(2.0, 19.0);
      _animatedMove(_mapController.camera.center, newZoom);
    }
  }

  void _goToUserLocation() {
    if (widget.userLocation == null) return;
    _animatedMove(widget.userLocation!, 17);
  }

  Future<void> _animatedMove(latlong.LatLng destLocation, double destZoom) async {
    if (!mounted) {
      return;
    }
    
    try {
      await _animatedMapController.animateTo(
        dest: destLocation,
        zoom: destZoom.clamp(2.0, 19.0),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint('Animation error: $e');
      // Fallback to immediate move
      if (mounted) {
        _mapController.move(destLocation, destZoom.clamp(2.0, 19.0));
      }
    }
  }

  void _toggleTheme() {
    if (mounted) {
      setState(() {
        _currentTheme = _currentTheme == _MapTheme.light ? _MapTheme.dark : _MapTheme.light;
      });
    }
  }
}

class _UserLocationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
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
                    cacheManager: _ModernMapState._profileImageCache,
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
    );
  }
}

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

class _CompassWidget extends StatelessWidget {
  final double heading;
  final VoidCallback onTap;

  const _CompassWidget({required this.heading, required this.onTap});

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
        child: Center(
          child: Transform.rotate(
            angle: heading * (pi / 180) * -1,
            child: Icon(
              Icons.navigation,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

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