import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as fmtc;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:sensors_plus/sensors_plus.dart';

import '../models/map_marker.dart';

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

/// Your beautiful ModernMap UI with ultra-smooth zoom performance optimizations
class SmoothModernMap extends StatefulWidget {
  final latlong.LatLng initialPosition;
  final Set<MapMarker> markers;
  final bool showUserLocation;
  final latlong.LatLng? userLocation;
  final String? userPhotoUrl;
  final bool isLocationRealTime;
  final void Function(MapMarker)? onMarkerTap;
  final void Function(latlong.LatLng center, double zoom)? onMapMoved;

  const SmoothModernMap({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.showUserLocation = true,
    this.userLocation,
    this.userPhotoUrl,
    this.isLocationRealTime = false,
    this.onMarkerTap,
    this.onMapMoved,
  });

  @override
  State<SmoothModernMap> createState() => _SmoothModernMapState();
}

enum _MapTheme { light, dark }

class _SmoothModernMapState extends State<SmoothModernMap>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  
  // Keep your original beautiful ride types UI
  final List<Map<String, dynamic>> rideTypes = [
    {
      'type': 'UberX',
      'price': '\$24-30',
      'time': '3 min',
      'icon': Icons.directions_car,
      'color': Colors.blue,
    },
    {
      'type': 'UberXL',
      'price': '\$31-37',
      'time': '5 min',
      'icon': Icons.airport_shuttle,
      'color': Colors.blue[800],
    },
    {
      'type': 'Comfort',
      'price': '\$28-34',
      'time': '4 min',
      'icon': Icons.airline_seat_recline_normal,
      'color': Colors.black,
    },
    {
      'type': 'Uber Black',
      'price': '\$45-52',
      'time': '7 min',
      'icon': Icons.directions_car,
      'color': Colors.black,
    },
  ];
  
  late final AnimatedMapController _animatedMapController;
  MapController get _mapController => _animatedMapController.mapController;
  _MapTheme _currentTheme = _MapTheme.light;
  double? _heading;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  bool _hasMagnetometer = false;

  // PERFORMANCE OPTIMIZATIONS - Keep your UI, optimize the performance
  late List<Marker> _cachedMarkers;
  Set<MapMarker>? _lastMarkersSet;
  final _markerCache = <String, Marker>{};
  
  // ULTRA-SMOOTH zoom optimizations
  bool _isZooming = false;
  Timer? _zoomDebounceTimer;
  Timer? _markerUpdateTimer;
  final _debouncer = _Debouncer(delay: const Duration(milliseconds: 50)); // Faster debouncing
  
  // Performance tracking
  bool _highPerformanceMode = true;

  @override
  void initState() {
    super.initState();
    // Faster animation for smoother feel - keep your animations but make them snappier
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Reduced from 800ms for smoother feel
    );
    _cachedMarkers = [];
    _startMagnetometer();
    WidgetsBinding.instance.addObserver(this);
    fmtc.FMTCStore('mainCache').manage.create();
  }

  @override
  void didUpdateWidget(SmoothModernMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update markers if they actually changed - PERFORMANCE OPTIMIZATION
    if (widget.markers != oldWidget.markers) {
      _scheduleMarkerUpdate();
    }
    
    // AUTO-CENTER: When user location becomes available for the first time, center the map
    if (widget.userLocation != null && 
        oldWidget.userLocation == null && 
        !_isZooming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.userLocation != null) {
          _animatedMapController.animateTo(
            dest: widget.userLocation!,
            zoom: 16.0,
          );
        }
      });
    }
  }

  // ULTRA-SMOOTH: Highly optimized marker updates
  void _scheduleMarkerUpdate() {
    if (_isZooming) return; // Never update during zoom
    
    _markerUpdateTimer?.cancel();
    _markerUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isZooming && _highPerformanceMode) {
        _buildAllMarkers();
      }
    });
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
    _markerUpdateTimer?.cancel();
    _zoomDebounceTimer?.cancel();
    _debouncer.dispose();
    super.dispose();
  }

  void _startMagnetometer() {
    if (_hasMagnetometer) return;
    
    try {
      _magnetometerSubscription?.cancel();
      _magnetometerSubscription = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          // ULTRA-SMOOTH: Skip all magnetometer updates during zoom or low performance mode
          if (!mounted || _isZooming || !_highPerformanceMode) return;
          
          final newHeading = (atan2(event.y, event.x) * 180 / pi) + 90;
          final normalizedHeading = newHeading < 0 ? newHeading + 360 : newHeading;
          
          // Only update if heading changed significantly (reduce noise and redraws)
          if (_heading == null || ((_heading! - normalizedHeading).abs() > 10)) {
            if (mounted && !_isZooming) {
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
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error initializing magnetometer: $e');
      if (mounted) {
        setState(() {
          _hasMagnetometer = false;
        });
      }
    }
  }

  // PERFORMANCE OPTIMIZED: Smart marker building with caching
  List<Marker> _buildAllMarkers() {
    // Skip updates during zoom for smooth performance
    if (_isZooming) return _cachedMarkers;
    
    // Quick equality check - skip if no changes
    if (_lastMarkersSet != null && 
        _lastMarkersSet!.length == widget.markers.length &&
        _lastMarkersSet!.containsAll(widget.markers)) {
      return _cachedMarkers;
    }

    final markers = <Marker>[];
    
    // Add user location marker with your original beautiful design - ALWAYS PRIORITIZE USER LOCATION
    if (widget.showUserLocation && widget.userLocation != null) {
      markers.insert(0, // Insert at beginning to ensure it's always visible
        Marker(
          point: widget.userLocation!,
          width: 60,
          height: 60,
          child: _UserLocationMarker(
            heading: _heading,
            photoUrl: widget.userPhotoUrl,
            isRealTime: widget.isLocationRealTime,
          ),
        ),
      );
    }
    
    // Add friend markers with caching for performance
    for (final mapMarker in widget.markers) {
      final cacheKey = '${mapMarker.point.latitude}_${mapMarker.point.longitude}_${mapMarker.label}';
      
      if (_markerCache.containsKey(cacheKey)) {
        markers.add(_markerCache[cacheKey]!);
      } else {
        final marker = _buildFriendMarker(mapMarker);
        _markerCache[cacheKey] = marker;
        markers.add(marker);
      }
    }
    
    _lastMarkersSet = Set.from(widget.markers);
    
    if (mounted) {
      setState(() {
        _cachedMarkers = markers;
      });
    }
    
    return markers;
  }

  // Beautiful friend marker with profile pictures
  Marker _buildFriendMarker(MapMarker mapMarker) {
    return Marker(
      point: mapMarker.point,
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => widget.onMarkerTap?.call(mapMarker),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: mapMarker.color ?? Colors.blue,
                shape: BoxShape.circle,
              ),
              child: mapMarker.photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        mapMarker.photoUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to initials if image fails to load
                          return _buildInitialsMarker(mapMarker);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildInitialsMarker(mapMarker);
                        },
                      ),
                    )
                  : _buildInitialsMarker(mapMarker),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build initials marker
  Widget _buildInitialsMarker(MapMarker mapMarker) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: mapMarker.color ?? Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          mapMarker.label?.substring(0, 1).toUpperCase() ?? 'F',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  // ULTRA-SMOOTH: Instant zoom with minimal overhead
  void _zoomBy(double delta) {
    if (_isZooming) return; // Prevent zoom spam
    
    HapticFeedback.lightImpact();
    _isZooming = true;
    _highPerformanceMode = false; // Disable all non-essential updates
    
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + delta).clamp(2.0, 19.0);
    
    // Use direct zoom instead of animation for instant response
    _mapController.move(_mapController.camera.center, newZoom);
    
    // Ultra-fast zoom end detection
    _zoomDebounceTimer?.cancel();
    _zoomDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _isZooming = false;
      _highPerformanceMode = true; // Re-enable updates
      _scheduleMarkerUpdate();
    });
  }

  void _goToUserLocation() {
    if (widget.userLocation != null) {
      HapticFeedback.mediumImpact();
      _animatedMapController.animateTo(
        dest: widget.userLocation!,
        zoom: 16.0,
      );
    }
  }

  void _toggleTheme() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentTheme = _currentTheme == _MapTheme.light ? _MapTheme.dark : _MapTheme.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // PERFORMANCE OPTIMIZED: Single tile layer for smooth zoom
            RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialPosition,
                  initialZoom: 15,
                  minZoom: 2,
                  maxZoom: 19,
                  
                  // ULTRA-SMOOTH: Optimized interaction settings for 60fps
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | 
                           InteractiveFlag.drag |
                           InteractiveFlag.doubleTapZoom,
                    enableMultiFingerGestureRace: true,
                    pinchZoomWinGestures: MultiFingerGesture.pinchZoom,
                    pinchMoveWinGestures: MultiFingerGesture.pinchMove,
                  ),
                  
                  onMapReady: () {
                    // AUTO-CENTER: Immediately center on user location when map is ready
                    if (widget.userLocation != null) {
                      _mapController.move(widget.userLocation!, 16.0);
                    }
                  },
                  
                  // ULTRA-SMOOTH: Minimal position change handling
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      _isZooming = true;
                      // Stop all non-essential updates during zoom
                      _magnetometerSubscription?.pause();
                    }
                    
                    // Ultra-fast debouncing for smooth zoom
                    _debouncer.run(() {
                      if (widget.onMapMoved != null && position.center != null && position.zoom != null) {
                        widget.onMapMoved!(position.center!, position.zoom!);
                      }
                      _isZooming = false;
                      // Resume magnetometer after zoom
                      _magnetometerSubscription?.resume();
                      // Delayed marker update to not interfere with zoom
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted && !_isZooming) {
                          _scheduleMarkerUpdate();
                        }
                      });
                    });
                  },
                ),
                
                children: [
                  // ULTRA-SMOOTH: Highly optimized tile layer for 60fps zoom
                  TileLayer(
                    urlTemplate: _currentTheme == _MapTheme.dark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.sundeep.groupsharing',
                    maxZoom: 19,
                    minZoom: 2,
                    retinaMode: false,
                    tileProvider: fmtc.FMTCStore('mainCache').getTileProvider(),
                    errorTileCallback: (TileImage tile, Object error, StackTrace? stackTrace) {
                      // Silent error handling
                    },
                  ),
                  
                  // ULTRA-SMOOTH: Conditional marker layer (hidden during zoom)
                  if (!_isZooming || _cachedMarkers.isEmpty)
                    MarkerLayer(
                      markers: _cachedMarkers,
                      rotate: false,
                    ),
                ],
              ),
            ),
            
            // ULTRA-SMOOTH: Simplified search bar (hidden during zoom)
            if (!_isZooming)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Where to?',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                ),
              ),
            
            // ULTRA-SMOOTH: Simplified location button (always visible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              right: 15,
              child: RepaintBoundary(
                child: FloatingActionButton(
                  heroTag: 'location',
                  mini: true,
                  backgroundColor: widget.userLocation != null ? Colors.blue : Colors.white,
                  elevation: 2,
                  onPressed: _goToUserLocation,
                  child: Icon(
                    Icons.my_location, 
                    color: widget.userLocation != null ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            
            // ULTRA-SMOOTH: Essential controls only (compass hidden during zoom)
            Positioned(
              bottom: 16,
              right: 16,
              child: RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compass only when not zooming
                    if (_hasMagnetometer && _heading != null && !_isZooming)
                      _CompassWidget(
                        heading: _heading!,
                        onTap: () {
                          if (mounted) {
                            _mapController.rotate(0);
                          }
                        },
                      ),
                    if (_hasMagnetometer && _heading != null && !_isZooming)
                      const SizedBox(height: 8),
                    
                    // Essential zoom controls (always visible)
                    _CircleIconButton(
                      icon: Icons.add,
                      onTap: () => _zoomBy(1),
                    ),
                    const SizedBox(height: 8),
                    _CircleIconButton(
                      icon: Icons.remove,
                      onTap: () => _zoomBy(-1),
                    ),
                    
                    // Theme toggle (hidden during zoom)
                    if (!_isZooming) ...[
                      const SizedBox(height: 8),
                      _CircleIconButton(
                        icon: _currentTheme == _MapTheme.light ? Icons.dark_mode : Icons.light_mode,
                        onTap: _toggleTheme,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // ULTRA-SMOOTH Performance indicator (debug mode only)
            if (kDebugMode && !_isZooming)
              Positioned(
                top: MediaQuery.of(context).padding.top + 140,
                left: 20,
                child: RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ULTRA-SMOOTH: ${_isZooming ? "ZOOMING" : "READY"}\n'
                      'Performance: ${_highPerformanceMode ? "HIGH" : "ZOOM"}\n'
                      'Markers: ${_cachedMarkers.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ULTRA-SMOOTH: Optimized compass widget with minimal repaints
class _CompassWidget extends StatelessWidget {
  final double heading;
  final VoidCallback? onTap;

  const _CompassWidget({
    required this.heading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Transform.rotate(
              angle: heading * pi / 180,
              child: const Icon(
                Icons.navigation,
                color: Colors.red,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ULTRA-SMOOTH: Optimized circle icon buttons with minimal overhead
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2, // Reduced elevation for better performance
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              icon,
              color: Colors.black87,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced user location marker with profile picture and real-time status indication
class _UserLocationMarker extends StatefulWidget {
  final double? heading;
  final String? photoUrl;
  final bool isRealTime;

  const _UserLocationMarker({
    this.heading,
    this.photoUrl,
    this.isRealTime = false,
  });

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Only animate if location is real-time
    if (widget.isRealTime) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_UserLocationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start/stop animation based on real-time status
    if (widget.isRealTime && !oldWidget.isRealTime) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isRealTime && oldWidget.isRealTime) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing circle - only visible for real-time location
            if (widget.isRealTime)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            
            // Main profile picture container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.isRealTime ? Colors.blue : Colors.grey[400],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                    ? Image.network(
                        widget.photoUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackAvatar();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildFallbackAvatar();
                        },
                      )
                    : _buildFallbackAvatar(),
              ),
            ),
            
            // Status indicator dot
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.isRealTime ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: widget.isRealTime
                    ? const Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 8,
                      )
                    : const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 8,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: widget.isRealTime ? Colors.blue : Colors.grey[400],
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}