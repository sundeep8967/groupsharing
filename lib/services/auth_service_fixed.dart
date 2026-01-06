import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google (with timeout fixes)
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow with timeout
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn()
          .timeout(const Duration(seconds: 30));
      
      if (googleUser == null) {
        // User cancelled the sign-in
        throw FirebaseAuthException(
          code: 'sign_in_cancelled',
          message: 'Sign in was cancelled by user',
        );
      }

      // Obtain the auth details from the request with timeout
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication
          .timeout(const Duration(seconds: 15));

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential with timeout
      final userCredential = await _auth.signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      
      // Create or update user document in Firestore (with timeout) - but don't block login
      _createOrUpdateUserDocumentInBackground(userCredential.user!);
      
      return userCredential;
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'timeout',
        message: 'Sign in timed out. Please try again.',
      );
    } catch (e) {
      print('Error during Google Sign In: $e');
      rethrow;
    }
  }

  // Create or update user document in background (non-blocking)
  void _createOrUpdateUserDocumentInBackground(User user) {
    Future.microtask(() async {
      try {
        await _createOrUpdateUserDocument(user)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Background user document creation failed: $e');
        // Don't throw - this is background operation
      }
    });
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      Map<String, dynamic> userData = {
        'email': user.email?.toLowerCase(),
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!userDoc.exists) {
        // New user - generate friend code
        final friendCode = await generateUniqueFriendCode();
        userData['friendCode'] = friendCode;
        userData['createdAt'] = FieldValue.serverTimestamp();
        print('Creating new user document with friend code: $friendCode');
      } else {
        // Existing user - check friend code
        final existingData = userDoc.data();
        final friendCode = existingData?['friendCode'];
        
        if (friendCode == null || friendCode.length != 6) {
          final newFriendCode = await generateUniqueFriendCode();
          userData['friendCode'] = newFriendCode;
          print('Generated new friend code for existing user: $newFriendCode');
        } else {
          userData['friendCode'] = friendCode;
          print('Using existing friend code: $friendCode');
        }
      }

      await userRef.set(userData, SetOptions(merge: true));
      print('User document updated successfully');
    } catch (e) {
      print('Error creating/updating user document: $e');
      rethrow;
    }
  }

  // Generate unique friend code
  Future<String> generateUniqueFriendCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    
    for (int attempt = 0; attempt < 10; attempt++) {
      final code = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
      );
      
      // Check if code already exists
      final existingUser = await _firestore
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (existingUser.docs.isEmpty) {
        return code;
      }
    }
    
    throw Exception('Failed to generate unique friend code after 10 attempts');
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  // Get user by friend code
  Future<Map<String, dynamic>?> getUserByFriendCode(String friendCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('friendCode', isEqualTo: friendCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {
          'uid': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      print('Error getting user by friend code: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      rethrow;
    }
  }

  // Update user data
  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await _firestore.collection('users').doc(user.uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }
}