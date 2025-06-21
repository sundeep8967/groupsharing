import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geofence_service/geofence_service.dart';
import '../models/geofence_model.dart';

class GeofenceRepository {
  GeofenceRepository(this.uid);

  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _geofenceCol =>
      _db.collection('users').doc(uid).collection('geofences');

  CollectionReference<Map<String, dynamic>> get _eventCol =>
      _db.collection('users').doc(uid).collection('geofenceEvents');

  Future<List<GeofenceModel>> fetchGeofences() async {
    final snap = await _geofenceCol.get();
    return snap.docs
        .map((d) => GeofenceModel.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> saveGeofence(GeofenceModel model) async {
    await _geofenceCol.doc(model.id).set(model.toMap());
  }

  Future<void> deleteGeofence(String id) async {
    await _geofenceCol.doc(id).delete();
  }

  Future<void> addEvent(Geofence geofence, GeofenceStatus status, Location location) async {
    await _eventCol.add({
      'geofenceId': geofence.id,
      'status': status.name,
      'lat': location.latitude,
      'lng': location.longitude,
      'ts': FieldValue.serverTimestamp(),
    });
  }
}
