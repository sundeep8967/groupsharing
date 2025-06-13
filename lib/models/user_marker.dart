import 'package:latlong2/latlong.dart';

class UserMarker {
  final String userId;
  final LatLng location;
  
  UserMarker({
    required this.userId,
    required this.location,
  });
}
