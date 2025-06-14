import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Assuming UserModel will be needed
import '../models/friendship_model.dart'; // Assuming FriendshipModel will be needed
import 'firebase_service.dart'; // For accessing Firestore collections

class FriendService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  // Corrected: Use FirebaseService.usersCollection directly or ensure it's correctly typed if assigned.
  // For simplicity, let's use FirebaseService.usersCollection directly in queries if _usersCollection is not specifically typed.
  // However, the existing structure `final CollectionReference _usersCollection = FirebaseService.usersCollection;` is fine.
  final CollectionReference<Map<String, dynamic>> _usersCollection = FirebaseService.usersCollection;
  final CollectionReference<Map<String, dynamic>> _friendshipsCollection = FirebaseService.friendshipsCollection;

  Future<UserModel?> findUserByFriendCode(String friendCode) async {
    print('[FriendService] findUserByFriendCode attempting to find code: $friendCode');
    try {
      final querySnapshot = await _usersCollection
          .where('friendCode', isEqualTo: friendCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        print('[FriendService] User found by friend code: ${userDoc.id}');
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);
      } else {
        print('[FriendService] No user found with friend code: $friendCode');
        return null;
      }
    } catch (e) {
      print('[FriendService] Error finding user by friend code: $e');
      return null;
    }
  }

  Future<UserModel?> findUserByEmail(String email) async {
    print('[FriendService] findUserByEmail attempting to find email: $email');
    // Normalize email to lowercase to ensure case-insensitive search,
    // assuming emails are stored consistently (e.g., lowercase).
    // If emails in Firestore might have mixed case, this search will be case-sensitive.
    // For a true case-insensitive search on Firestore, more complex solutions are needed
    // (e.g., storing a lowercase version of the email).
    // For now, we'll assume emails are stored in a queryable, consistent case (e.g. via app logic).
    String normalizedEmail = email.toLowerCase();
    try {
      final querySnapshot = await _usersCollection
          .where('email', isEqualTo: normalizedEmail) // Using normalizedEmail for query
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        print('[FriendService] User found by email: ${userDoc.id}');
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);
      } else {
        print('[FriendService] No user found with email: $email (queried as $normalizedEmail)');
        return null;
      }
    } catch (e) {
      print('[FriendService] Error finding user by email: $e');
      return null;
    }
  }

  // Method to send a friend request
  Future<void> sendFriendRequest(String currentUserUID, String targetUserUID) async {
    print('[FriendService] Attempting to send friend request from $currentUserUID to $targetUserUID');

    if (currentUserUID == targetUserUID) {
      print('[FriendService] User cannot send a friend request to themselves.');
      // Optionally, throw an exception or return a status
      return;
    }

    try {
      // Check 1: Request from currentUserUID to targetUserUID
      final existingRequestQuery1 = await _friendshipsCollection
          .where('userId', isEqualTo: currentUserUID)
          .where('friendId', isEqualTo: targetUserUID)
          .limit(1)
          .get();

      // Check 2: Request from targetUserUID to currentUserUID
      final existingRequestQuery2 = await _friendshipsCollection
          .where('userId', isEqualTo: targetUserUID)
          .where('friendId', isEqualTo: currentUserUID)
          .limit(1)
          .get();

      if (existingRequestQuery1.docs.isNotEmpty || existingRequestQuery2.docs.isNotEmpty) {
        // You might want to check the status of the existing request.
        // For example, if a request was 'rejected', you might allow sending a new one.
        // Or if it's 'pending' or 'accepted', you prevent a new one.
        // For now, let's assume any existing record means no new request.
        print('[FriendService] A friendship record already exists between $currentUserUID and $targetUserUID.');
        // Optionally, throw an exception or return a status indicating this.
        // For example: throw Exception('Friendship request already exists or has been processed.');
        return;
      }

      // If no existing request, create a new one
      final newRequestData = {
        'userId': currentUserUID,
        'friendId': targetUserUID,
        'status': FriendshipStatus.pending.toString(), // Use enum value
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _friendshipsCollection.add(newRequestData);
      print('[FriendService] Friend request sent successfully from $currentUserUID to $targetUserUID.');

    } catch (e) {
      print('[FriendService] Error sending friend request: $e');
      // Re-throw the exception to be handled by the caller if needed
      throw Exception('Failed to send friend request: ${e.toString()}');
    }
  }

  // Method to accept a friend request
  Future<void> acceptFriendRequest(String requestID) async {
    print('[FriendService] Attempting to accept friend request: $requestID');
    try {
      final requestDocRef = _friendshipsCollection.doc(requestID);
      final requestSnapshot = await requestDocRef.get();

      if (!requestSnapshot.exists) {
        throw Exception('Friend request document not found.');
      }

      final requestData = requestSnapshot.data();
      if (requestData == null) {
        throw Exception('Friend request data is null.');
      }

      final String senderUID = requestData['userId'];
      final String receiverUID = requestData['friendId'];

      // Update the friendship document status to accepted
      await requestDocRef.update({
        'status': FriendshipStatus.accepted.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add users to each other's friends lists (in the users collection)
      // This assumes users documents have a 'friends' array field.
      final senderUserDocRef = _usersCollection.doc(senderUID);
      await senderUserDocRef.update({
        'friends': FieldValue.arrayUnion([receiverUID]),
        'updatedAt': FieldValue.serverTimestamp(), // Also update user's updatedAt
      });

      final receiverUserDocRef = _usersCollection.doc(receiverUID);
      await receiverUserDocRef.update({
        'friends': FieldValue.arrayUnion([senderUID]),
        'updatedAt': FieldValue.serverTimestamp(), // Also update user's updatedAt
      });

      print('[FriendService] Friend request $requestID accepted successfully.');

    } catch (e) {
      print('[FriendService] Error accepting friend request $requestID: $e');
      throw Exception('Failed to accept friend request: ${e.toString()}');
    }
  }

  // Method to reject a friend request
  Future<void> rejectFriendRequest(String requestID) async {
    print('[FriendService] Attempting to reject friend request: $requestID');
    try {
      final requestDocRef = _friendshipsCollection.doc(requestID);
      // Check if document exists before updating (optional, update won't fail but good practice)
      // final requestSnapshot = await requestDocRef.get();
      // if (!requestSnapshot.exists) {
      //   throw Exception('Friend request document not found.');
      // }

      await requestDocRef.update({
        'status': FriendshipStatus.rejected.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('[FriendService] Friend request $requestID rejected successfully.');
    } catch (e) {
      print('[FriendService] Error rejecting friend request $requestID: $e');
      throw Exception('Failed to reject friend request: ${e.toString()}');
    }
  }

  // Method to get pending friend requests for the current user
  Stream<List<FriendshipModel>> getPendingRequests(String currentUserUID) {
    print('[FriendService] getPendingRequests called for user: $currentUserUID');
    try {
      return _friendshipsCollection
          .where('friendId', isEqualTo: currentUserUID) // Requests sent TO the current user
          .where('status', isEqualTo: FriendshipStatus.pending.toString())
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return FriendshipModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      }).handleError((error) {
        print('[FriendService] Error in getPendingRequests stream: $error');
        // Optionally, return an empty list or a stream with an error
        return []; // Or throw error;
      });
    } catch (e) {
      print('[FriendService] Exception caught while setting up getPendingRequests stream: $e');
      return Stream.value([]); // Return empty stream on initial setup error
    }
  }

  // Method to get a list of accepted friends for the current user
  Stream<List<UserModel>> getFriends(String currentUserUID) {
    print('[FriendService] getFriends called for user: $currentUserUID');
    try {
      return _usersCollection.doc(currentUserUID).snapshots().asyncMap((userDocSnapshot) async {
        if (!userDocSnapshot.exists || userDocSnapshot.data() == null) {
          print('[FriendService] Current user document not found or data is null for $currentUserUID');
          return <UserModel>[];
        }

        final List<String> friendUIDs = List<String>.from(userDocSnapshot.data()!['friends'] ?? []);

        if (friendUIDs.isEmpty) {
          print('[FriendService] User $currentUserUID has no friends in their list.');
          return <UserModel>[];
        }

        print('[FriendService] User $currentUserUID friend UIDs: $friendUIDs');

        final List<UserModel> friendsList = [];
        for (String uid in friendUIDs) {
          final friendDocSnapshot = await _usersCollection.doc(uid).get();
          if (friendDocSnapshot.exists && friendDocSnapshot.data() != null) {
            friendsList.add(UserModel.fromMap(friendDocSnapshot.data()!, friendDocSnapshot.id));
          } else {
            print('[FriendService] Friend document not found for UID: $uid');
            // Optionally add a placeholder or skip if a friend's doc is missing
          }
        }
        print('[FriendService] Fetched ${friendsList.length} friend models for user $currentUserUID');
        return friendsList;
      }).handleError((error) {
        print('[FriendService] Error in getFriends stream for user $currentUserUID: $error');
        return <UserModel>[]; // Return an empty list on error
      });
    } catch (e) {
      print('[FriendService] Exception caught while setting up getFriends stream for $currentUserUID: $e');
      return Stream.value([]); // Return empty stream on initial setup error
    }
  }

  Future<UserModel?> getUserDetails(String uid) async {
    print('[FriendService] getUserDetails called for UID: $uid');
    try {
      final docSnapshot = await _usersCollection.doc(uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromMap(docSnapshot.data()!, docSnapshot.id);
      }
      return null;
    } catch (e) {
      print('[FriendService] Error fetching user details for $uid: $e');
      return null;
    }
  }
}
