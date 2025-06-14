import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Represents a marker on the map with an optional onTap callback.
class MapMarker {
  final String id;
  final LatLng point;
  final Widget? icon;
  final String? label;
  final Color? color;
  final void Function()? onTap;
  final bool isCurrentUser;
  final double? bearing;
  final double? accuracy;

  const MapMarker({
    required this.id,
    required this.point,
    this.icon,
    this.label,
    this.color,
    this.onTap,
    this.isCurrentUser = false,
    this.bearing,
    this.accuracy,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMarker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
