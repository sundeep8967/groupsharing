import 'dart:math'; // Added for Random
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        String userId = userCredential.user!.uid;
        // Add print statement here
        print('[TESTING] User signed in with email. User ID: $userId. Checking friend code...');
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

        String? friendCode;
        if (userDoc.exists) {
          // Attempt to get the friend code
          try {
            friendCode = (userDoc.data() as Map<String, dynamic>)['friendCode'] as String?;
          } catch (e) {
            // Field might not exist or is not a string, treat as missing
            friendCode = null;
          }
        }

        if (friendCode == null || friendCode.length != 6) {
          // If friend code is missing or invalid, generate and save a new one
          print('[TESTING] friendCode missing or invalid. Current value: $friendCode. Generating new one...');
          String newFriendCode = await generateUniqueFriendCode();
          print('[TESTING] Generated new friendCode for existing user: $newFriendCode');
          // Add print statement here
          print('[TESTING] Updating user $userId with new friendCode: $newFriendCode');
          await _firestore.collection('users').doc(userId).update({
            'friendCode': newFriendCode,
          });
        } else {
          // Add print statement here
          print('[TESTING] Existing valid friendCode found: $friendCode');
        }
      }
      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      // Add print statement here
      print('[TESTING] Registering new user. displayName: $displayName. Generating friend code...');
      final UserCredential userCredential = 
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (userCredential.user != null) {
        String newFriendCode = await generateUniqueFriendCode(); // generateUniqueFriendCode is now public
        // Add print statement here
        print('[TESTING] Generated friendCode for new user: $newFriendCode');
        await _createUserDocument(
          userCredential.user!,
          displayName,
          friendCode: newFriendCode
        );
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign In was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      // Create/Update user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(
          userCredential.user!,
          userCredential.user!.displayName ?? 'User',
        );
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('No user is currently signed in. Cannot delete account.');
    }

    final String userId = user.uid;

    try {
      // Step 1: Delete user-specific sub-collections (e.g., saved_places)
      // This method is expected to be in FirebaseService and will be implemented later.
      await FirebaseService.deleteUserSubCollections(userId);
      print('Successfully deleted user sub-collections for $userId.');

      // Step 2: Delete the user's document from the 'users' collection
      // This method is expected to be in FirebaseService and will be implemented later.
      await FirebaseService.deleteUserDocument(userId);
      print('Successfully deleted user document for $userId from Firestore.');

      // Step 3: Delete the user from Firebase Authentication
      await user.delete();
      print('Successfully deleted user account from Firebase Authentication for $userId.');

      // Optionally, sign out the user from Google Sign-In if they used it
      // This might be redundant if user.delete() handles it, but good for thoroughness
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        print('Signed out from Google after account deletion.');
      }

    } on FirebaseAuthException catch (e) {
      print('Error deleting user from Firebase Authentication: ${e.code} - ${e.message}');
      // Specific handling for re-authentication if needed
      if (e.code == 'requires-recent-login') {
        throw Exception(
            'This operation is sensitive and requires recent authentication. Please log in again before retrying.');
      }
      throw Exception('Failed to delete Firebase Auth user: ${e.message}');
    } catch (e) {
      print('An error occurred during account deletion for user $userId: $e');
      throw Exception('Failed to delete user account: $e');
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String displayName, {String? friendCode}) async {
    // Add print statement here
    print('[TESTING] _createUserDocument called. User ID: ${user.uid}, DisplayName: $displayName, FriendCode: $friendCode');
    final UserModel newUser = UserModel(
      id: user.uid,
      email: user.email!,
      displayName: displayName,
      photoUrl: user.photoURL, // Add photoUrl from the Firebase User object
    );

    Map<String, dynamic> userData = newUser.toMap();

    if (friendCode != null) {
      userData['friendCode'] = friendCode;
    }

    // Add/update timestamps
    userData['createdAt'] = FieldValue.serverTimestamp();
    userData['updatedAt'] = FieldValue.serverTimestamp();

    // Add print statement here
    print('[TESTING] Saving new user to Firestore. Data: $userData');
    await _firestore.collection('users').doc(user.uid).set(userData);
  }

  // Generate a unique friend code
  Future<String> generateUniqueFriendCode() async {
    // Add print statement here
    print('[TESTING] generateUniqueFriendCode called.');
    String code;
    bool exists = true;
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    do {
      code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
      // Use the existing _firestore instance
      final query = await _firestore.collection('users').where('friendCode', isEqualTo: code).limit(1).get();
      exists = query.docs.isNotEmpty;
    } while (exists);
    // Add print statement here
    print('[TESTING] Unique friendCode generated: $code');
    return code;
  }

  // Handle authentication exceptions
  Exception _handleAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return Exception('No user found with this email.');
        case 'wrong-password':
          return Exception('Wrong password provided.');
        case 'email-already-in-use':
          return Exception('Email is already registered.');
        case 'invalid-email':
          return Exception('Invalid email address.');
        case 'weak-password':
          return Exception('Password is too weak.');
        default:
          return Exception('Authentication error: ${e.message}');
      }
    }
    return Exception('An unexpected error occurred.');
  }
}
