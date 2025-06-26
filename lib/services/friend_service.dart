import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Assuming UserModel will be needed
import '../models/friendship_model.dart'; // Assuming FriendshipModel will be needed
import '../models/friend_relationship.dart'; // New model for friend relationships
import 'firebase_service.dart'; // For accessing Firestore collections

class FriendService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
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
          .where('from', isEqualTo: currentUserUID) // Changed: userId -> from
          .where('to', isEqualTo: targetUserUID)     // Changed: friendId -> to
          .limit(1)
          .get();

      // Check 2: Request from targetUserUID to currentUserUID
      final existingRequestQuery2 = await _friendshipsCollection
          .where('from', isEqualTo: targetUserUID)   // Changed: userId -> from
          .where('to', isEqualTo: currentUserUID)   // Changed: friendId -> to
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
        'from': currentUserUID, // Changed: userId -> from
        'to': targetUserUID,   // Changed: friendId -> to
        'status': FriendshipStatus.pending.toString(), // Use enum value
        'category': FriendshipCategory.family.toString(), // Default to family
        'timestamp': FieldValue.serverTimestamp(), // Changed: createdAt -> timestamp
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

      final String senderUID = requestData['from']; // Changed: userId -> from
      final String receiverUID = requestData['to'];   // Changed: friendId -> to

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

      await requestDocRef.update({
        'status': FriendshipStatus.rejected.toString(),
        'updatedAt': FieldValue.serverTimestamp(), // Ensured updatedAt is set
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
          .where('to', isEqualTo: currentUserUID) // Changed: friendId -> to
          .where('status', isEqualTo: FriendshipStatus.pending.toString())
          .snapshots()
          .map((snapshot) {
        // Sort in memory instead of using orderBy to avoid index requirement
        final docs = snapshot.docs.map((doc) {
          return FriendshipModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        // Sort by timestamp in descending order (newest first)
        docs.sort((a, b) {
          final aTimestamp = a.timestamp;
          final bTimestamp = b.timestamp;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });
        
        return docs;
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

  // Method to get pending friend requests sent by the current user
  Stream<List<FriendshipModel>> getSentRequests(String currentUserUID) {
    print('[FriendService] getSentRequests called for user: $currentUserUID (pending only)');
    try {
      return _friendshipsCollection // This now correctly points to 'friend_requests'
          .where('from', isEqualTo: currentUserUID) // Requests sent BY the current user
          .where('status', isEqualTo: FriendshipStatus.pending.toString()) // Only pending requests
          .snapshots()
          .map((snapshot) {
        // Sort in memory instead of using orderBy to avoid index requirement
        final docs = snapshot.docs.map((doc) {
          return FriendshipModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        // Sort by timestamp in descending order (newest first)
        docs.sort((a, b) {
          final aTimestamp = a.timestamp;
          final bTimestamp = b.timestamp;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });
        
        return docs;
      }).handleError((error) {
        print('[FriendService] Error in getSentRequests stream: $error');
        return [];
      });
    } catch (e) {
      print('[FriendService] Exception caught while setting up getSentRequests stream: $e');
      return Stream.value([]);
    }
  }

  Future<void> cancelSentRequest(String requestID, String currentUserUID) async {
    print('[FriendService] Attempting to cancel sent request: $requestID by user: $currentUserUID');
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

      // Verify that the current user is the sender of this request
      if (requestData['from'] != currentUserUID) {
        print('[FriendService] User $currentUserUID is not authorized to cancel request $requestID.');
        throw Exception('You are not authorized to cancel this request.');
      }

      await requestDocRef.delete();
      print('[FriendService] Sent request $requestID cancelled successfully by $currentUserUID.');

    } catch (e) {
      print('[FriendService] Error cancelling sent request $requestID: $e');
      // Re-throw to be handled by the UI
      throw Exception('Failed to cancel sent request: ${e.toString()}');
    }
  }

  /// Get friends with their categories
  Stream<List<FriendRelationship>> getFriendsWithCategories(String currentUserUID) {
    print('[FriendService] getFriendsWithCategories called for user: $currentUserUID');
    try {
      return _friendshipsCollection
          .where('status', isEqualTo: FriendshipStatus.accepted.toString())
          .snapshots()
          .asyncMap((snapshot) async {
        
        final List<FriendRelationship> friendRelationships = [];
        
        for (final doc in snapshot.docs) {
          final friendshipData = doc.data() as Map<String, dynamic>;
          final friendship = FriendshipModel.fromMap(friendshipData, doc.id);
          
          // Determine if current user is 'from' or 'to' to get the friend's ID
          String friendId;
          if (friendship.from == currentUserUID) {
            friendId = friendship.to;
          } else if (friendship.to == currentUserUID) {
            friendId = friendship.from;
          } else {
            continue; // This friendship doesn't involve the current user
          }
          
          // Get friend's user data
          final friendDoc = await _usersCollection.doc(friendId).get();
          if (friendDoc.exists && friendDoc.data() != null) {
            final friendUser = UserModel.fromMap(friendDoc.data()!, friendDoc.id);
            
            friendRelationships.add(FriendRelationship(
              user: friendUser,
              category: friendship.category,
              friendshipId: doc.id,
            ));
          }
        }
        
        print('[FriendService] Fetched ${friendRelationships.length} friend relationships for user $currentUserUID');
        return friendRelationships;
      }).handleError((error) {
        print('[FriendService] Error in getFriendsWithCategories stream for user $currentUserUID: $error');
        return <FriendRelationship>[]; // Return an empty list on error
      });
    } catch (e) {
      print('[FriendService] Exception caught while setting up getFriendsWithCategories stream for $currentUserUID: $e');
      return Stream.value([]); // Return empty stream on initial setup error
    }
  }

  /// Update friendship category
  Future<void> updateFriendshipCategory(String friendshipId, FriendshipCategory newCategory) async {
    print('[FriendService] Attempting to update friendship category: $friendshipId to $newCategory');
    try {
      await _friendshipsCollection.doc(friendshipId).update({
        'category': newCategory.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('[FriendService] Friendship category updated successfully for $friendshipId');
    } catch (e) {
      print('[FriendService] Error updating friendship category: $e');
      throw Exception('Failed to update friendship category: ${e.toString()}');
    }
  }

  /// Get friendship details between two users
  Future<FriendshipModel?> getFriendshipBetweenUsers(String user1Id, String user2Id) async {
    print('[FriendService] Getting friendship between $user1Id and $user2Id');
    try {
      // Check both directions since friendship can be initiated by either user
      final query1 = await _friendshipsCollection
          .where('from', isEqualTo: user1Id)
          .where('to', isEqualTo: user2Id)
          .where('status', isEqualTo: FriendshipStatus.accepted.toString())
          .limit(1)
          .get();
      
      if (query1.docs.isNotEmpty) {
        return FriendshipModel.fromMap(query1.docs.first.data(), query1.docs.first.id);
      }
      
      final query2 = await _friendshipsCollection
          .where('from', isEqualTo: user2Id)
          .where('to', isEqualTo: user1Id)
          .where('status', isEqualTo: FriendshipStatus.accepted.toString())
          .limit(1)
          .get();
      
      if (query2.docs.isNotEmpty) {
        return FriendshipModel.fromMap(query2.docs.first.data(), query2.docs.first.id);
      }
      
      return null;
    } catch (e) {
      print('[FriendService] Error getting friendship between users: $e');
      return null;
    }
  }
}
