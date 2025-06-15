import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Google Sign-In only
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _authService.signInWithGoogle();
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
      final user = _user;
      if (user != null) {
        // Add print statement here
        print('[TESTING] User signed in with Google. User ID: ${user.uid}. Checking/generating friend code...');
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnap = await userDoc.get();
        // Add print statement here
        print('[TESTING] Firestore docSnap for Google user: ${docSnap.data()}');
        String? friendCode = docSnap.data()?['friendCode'];
        bool generatedNewCode = false;
        if (friendCode == null || friendCode.length != 6) {
          friendCode = await _authService.generateUniqueFriendCode(); // Changed to use AuthService
          generatedNewCode = true;
          // Add print statement here
          print('[TESTING] Generated/obtained friendCode for Google user: $friendCode');
        } else {
          // Add print statement here
          print('[TESTING] Existing valid friendCode found for Google user: $friendCode');
        }

        Map<String, dynamic> userDataToSet = {
          'email': user.email?.toLowerCase(),
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'friendCode': friendCode, // This is the determined friendCode
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!docSnap.exists) {
          userDataToSet['createdAt'] = FieldValue.serverTimestamp();
        }

        // Updated print statement to reflect actual data being set (excluding non-serializable FieldValue for direct printing if needed)
        // For logging, it's often better to log the map before FieldValue is applied if you need to see the structure.
        // However, for this test, we'll log it as is, understanding FieldValue won't be directly visible.
        print('[TESTING] Saving/updating Google user data to Firestore. Data being set: $userDataToSet');

        await userDoc.set(userDataToSet, SetOptions(merge: true));
      }
    } catch (e) {
      print('Google sign in error: \\${e.toString()}');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    if (_user != null) {
      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  // _generateUniqueFriendCode method removed
}
