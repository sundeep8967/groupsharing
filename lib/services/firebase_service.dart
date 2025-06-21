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
      _firestore.collection('friend_requests'); // Changed collection name

  static CollectionReference<Map<String, dynamic>> savedPlacesCollection(String userId) =>
      usersCollection.doc(userId).collection('saved_places');

  // --- User Data Deletion Methods ---

  /// Deletes the user's main document from the 'users' collection.
  static Future<void> deleteUserDocument(String userId) async {
    try {
      await usersCollection.doc(userId).delete();
      print('FirebaseService: User document $userId deleted successfully.');
    } catch (e) {
      print('FirebaseService: Error deleting user document $userId: $e');
      throw Exception('Failed to delete user document: $e');
    }
  }

  /// Deletes all documents within specified sub-collections for a user.
  /// Currently focuses on the 'saved_places' sub-collection.
  static Future<void> deleteUserSubCollections(String userId) async {
    // Delete 'saved_places' sub-collection
    try {
      final savedPlaces = savedPlacesCollection(userId);
      final snapshot = await savedPlaces.get();

      if (snapshot.docs.isEmpty) {
        print('FirebaseService: No documents found in saved_places for user $userId. Nothing to delete.');
        return;
      }

      // Using a batch for potentially more efficient deletion, though individual deletes work too.
      final WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('FirebaseService: Successfully deleted ${snapshot.docs.length} documents from saved_places for user $userId.');

    } catch (e) {
      print('FirebaseService: Error deleting saved_places for user $userId: $e');
      // It's important to decide if this error should halt the entire account deletion.
      // For now, we rethrow, but in a more complex scenario, one might log and continue.
      throw Exception('Failed to delete saved_places sub-collection: $e');
    }

    // Add loops for other sub-collections here if needed in the future
    // e.g., user_activity, user_preferences etc.
    // For example:
    // try {
    //   final anotherSubCollection = usersCollection.doc(userId).collection('another_sub_collection');
    //   final snapshot = await anotherSubCollection.get();
    //   final WriteBatch batch = _firestore.batch();
    //   for (var doc in snapshot.docs) {
    //     batch.delete(doc.reference);
    //   }
    //   await batch.commit();
    //   print('FirebaseService: Successfully deleted documents from another_sub_collection for user $userId.');
    // } catch (e) {
    //   print('FirebaseService: Error deleting another_sub_collection for user $userId: $e');
    //   throw Exception('Failed to delete another_sub_collection: $e');
    // }
  }
}
