import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Auth instance getter
  static FirebaseAuth get auth => _auth;

  // Firestore instance getter
  static FirebaseFirestore get firestore => _firestore;

  // Storage instance getter
  static FirebaseStorage get storage => _storage;

  // Collections references
  static CollectionReference<Map<String, dynamic>> get usersCollection => 
      _firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get locationsCollection =>
      _firestore.collection('locations');

  static CollectionReference<Map<String, dynamic>> get friendshipsCollection =>
      _firestore.collection('friendships');
}
