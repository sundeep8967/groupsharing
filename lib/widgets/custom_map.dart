import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';

class CustomMap extends StatefulWidget {
  final List<UserModel> familyMembers;
  final Map<String, LocationModel?> memberLocations;
  final double? initialZoom;
  final LatLng? initialCenter;

  const CustomMap({
    Key? key,
    required this.familyMembers,
    required this.memberLocations,
    this.initialZoom = 12.0,
    this.initialCenter,
  }) : super(key: key);

  @override
  State<CustomMap> createState() => _CustomMapState();
}

class _CustomMapState extends State<CustomMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng _center = const LatLng(37.7749, -122.4194); // Default to San Francisco

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didUpdateWidget(CustomMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberLocations != widget.memberLocations ||
        oldWidget.familyMembers != widget.familyMembers) {
      _updateMarkers();
    }
  }

  void _initializeMap() {
    _updateMarkers();
    _calculateCenter();
  }

  void _calculateCenter() {
    if (widget.memberLocations.isNotEmpty) {
      final validLocations = widget.memberLocations.values
          .where((location) => location != null)
          .cast<LocationModel>()
          .toList();

      if (validLocations.isNotEmpty) {
        double totalLat = 0;
        double totalLng = 0;
        
        for (final location in validLocations) {
          totalLat += location.latitude;
          totalLng += location.longitude;
        }
        
        setState(() {
          _center = LatLng(
            totalLat / validLocations.length,
            totalLng / validLocations.length,
          );
        });
      }
    }
  }

  void _updateMarkers() {
    final Set<Marker> newMarkers = {};

    for (final member in widget.familyMembers) {
      final location = widget.memberLocations[member.uid];
      if (location != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(member.uid),
            position: LatLng(location.latitude, location.longitude),
            infoWindow: InfoWindow(
              title: member.displayName,
              snippet: _getLocationSnippet(location),
            ),
            icon: _getMarkerIcon(member),
            onTap: () => _onMarkerTapped(member, location),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  BitmapDescriptor _getMarkerIcon(UserModel member) {
    // For now, use default markers with different colors based on relationship
    switch (member.relationship?.toLowerCase()) {
      case 'spouse':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'child':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'parent':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  String _getLocationSnippet(LocationModel location) {
    final timeDiff = DateTime.now().difference(location.timestamp);
    if (timeDiff.inMinutes < 5) {
      return 'Live location';
    } else if (timeDiff.inMinutes < 60) {
      return '${timeDiff.inMinutes} min ago';
    } else if (timeDiff.inHours < 24) {
      return '${timeDiff.inHours} hours ago';
    } else {
      return '${timeDiff.inDays} days ago';
    }
  }

  void _onMarkerTapped(UserModel member, LocationModel location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMemberLocationSheet(member, location),
    );
  }

  Widget _buildMemberLocationSheet(UserModel member, LocationModel location) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Member info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF4CAF50),
                backgroundImage: member.profileImageUrl != null
                    ? NetworkImage(member.profileImageUrl!)
                    : null,
                child: member.profileImageUrl == null
                    ? Text(
                        member.displayName.isNotEmpty 
                            ? member.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _getLocationSnippet(location),
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Location details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildLocationDetail(
                  Icons.location_on,
                  'Coordinates',
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 12),
                _buildLocationDetail(
                  Icons.speed,
                  'Speed',
                  '${location.speed?.toStringAsFixed(1) ?? '0'} km/h',
                ),
                const SizedBox(height: 12),
                _buildLocationDetail(
                  Icons.gps_fixed,
                  'Accuracy',
                  '${location.accuracy?.toStringAsFixed(1) ?? 'Unknown'} m',
                ),
                if (location.altitude != null) ...[
                  const SizedBox(height: 12),
                  _buildLocationDetail(
                    Icons.height,
                    'Altitude',
                    '${location.altitude!.toStringAsFixed(1)} m',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _getDirections(location),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareLocation(location),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _getDirections(LocationModel location) {
    // Implement directions functionality
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening directions...'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _shareLocation(LocationModel location) {
    // Implement share functionality
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location shared!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Apply dark theme to map
    _mapController?.setMapStyle('''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "administrative.country",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9e9e9e"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#bdbdbd"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#181818"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#1b1b1b"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#2c2c2c"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8a8a8a"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#373737"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#3c3c3c"
          }
        ]
      },
      {
        "featureType": "road.highway.controlled_access",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#4e4e4e"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#616161"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#000000"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#3d3d3d"
          }
        ]
      }
    ]
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: widget.initialCenter ?? _center,
        zoom: widget.initialZoom ?? 12.0,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      trafficEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: false,
      mapType: MapType.normal,
      onTap: (LatLng position) {
        // Handle map tap if needed
      },
    );
  }
}