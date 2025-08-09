import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
// Somewhere accessible, e.g., in auth_provider.dart or a separate auth_result.dart
class AuthResult {
  final bool success;
  final String? error; // Use error codes or messages
  // final firebase_auth.User? user; // Can also include the user, though provider state is usually better

  AuthResult({required this.success, this.error});
}
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
  Future<AuthResult> signInWithGoogle() async { // <--- Changed return type
    try {
      _isLoading = true;
      notifyListeners();

      // Call the actual auth service, which should ideally also return
      // a boolean or an AuthResult to confirm success/cancellation/failure.
      // For now, let's assume _authService.signInWithGoogle() throws on failure.
      await _authService.signInWithGoogle();

      _user = FirebaseAuth.instance.currentUser;
      notifyListeners(); // Notify after _user is updated

      final user = _user;
      if (user != null) {
        developer.log('[TESTING] User signed in with Google. User ID: \\${user.uid}. Checking/generating friend code...');
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnap = await userDoc.get();
        print('[TESTING] Firestore docSnap for Google user: \\${docSnap.data()}');

        String? friendCode = docSnap.data()?['friendCode'];
        if (!docSnap.exists || docSnap.data() == null) {
          // If document does not exist, create a new one
          friendCode = await _authService.generateUniqueFriendCode();
          developer.log('[TESTING] Creating new user document for Google user: \\${user.uid}');
          Map<String, dynamic> userDataToSet = {
            'email': user.email?.toLowerCase(),
            'displayName': user.displayName,
            'photoUrl': user.photoURL,
            'friendCode': friendCode,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await userDoc.set(userDataToSet);
        } else {
          if (friendCode == null || friendCode.length != 6) {
            friendCode = await _authService.generateUniqueFriendCode();
            developer.log('[TESTING] Generated/obtained friendCode for Google user: \\${friendCode}');
          } else {
            developer.log('[TESTING] Existing valid friendCode found for Google user: \\${friendCode}');
          }

          Map<String, dynamic> userDataToSet = {
            'email': user.email?.toLowerCase(),
            'displayName': user.displayName,
            'photoUrl': user.photoURL,
            'friendCode': friendCode,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (!docSnap.exists) {
            userDataToSet['createdAt'] = FieldValue.serverTimestamp();
          }

          developer.log('[TESTING] Saving/updating Google user data to Firestore. Data being set: \\${userDataToSet}');
          await userDoc.set(userDataToSet, SetOptions(merge: true));
        }

        return AuthResult(success: true); // <--- Return success
      } else {
        // This case should ideally be handled by _authService.signInWithGoogle()
        // throwing an error or returning a specific cancellation state.
        // If it still reaches here, it means the Firebase current user is null
        // after the sign-in flow completed without error.
        developer.log('[TESTING] signInWithGoogle completed but FirebaseAuth.instance.currentUser is null.');
        return AuthResult(success: false, error: 'Sign-in flow completed without an active user.');
      }
    } on Exception catch (e) { // Catch all exceptions from _authService.signInWithGoogle()
      print('Google sign in error in AuthProvider: ${e.toString()}');
      if (e.toString().contains('cancelled') || e.toString().contains('SIGN_IN_CANCELLED')) {
         return AuthResult(success: false, error: 'SIGN_IN_CANCELLED'); // Specific error for cancellation
      }
      return AuthResult(success: false, error: e.toString()); // Pass the error message
    } finally {
      _isLoading = false;
      // Fire-and-forget permission request after sign-in success
      if (_user != null) {
        _ensureLocationPermissions();
      }
      notifyListeners();
    }
  }

  // Minimal permission prompt right after successful login
  Future<void> _ensureLocationPermissions() async {
    try {
      // Ensure services are enabled
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        await Geolocator.openLocationSettings();
      }

      // Request permissions
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      // Try to upgrade to Always if possible (background)
      if (perm == LocationPermission.whileInUse) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      developer.log('Permission prompt after login failed: $e');
    }
  }

 Future<bool> signOut() async {
  try {
    _isLoading = true;
    notifyListeners();
    
    await _authService.signOut();
    _user = null;
    notifyListeners();
    
    return true; // Success
    
  } catch (e) {
    developer.log('Sign out error: $e');
    return false; // Failed
    
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

  Future<DeleteAccountResult> deleteUserAccount() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.deleteUserAccount();
      
      // Clear user data if deletion was successful
      _user = null;
      await _clearUserData();
      notifyListeners();
      
      return DeleteAccountResult.success();
      
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors
      if (e.code == 'requires-recent-login') {
        return DeleteAccountResult.requiresReauth();
      } else if (e.code == 'user-not-found') {
        return DeleteAccountResult.userNotFound();
      }
      return DeleteAccountResult.error(e.message ?? 'Unknown error occurred');
      
    } catch (e) {
      return DeleteAccountResult.error(e.toString());
      
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper method to clear user data
  Future<void> _clearUserData() async {
    // Clear any cached user data, preferences, etc.
    // Example:
    // await _preferencesService.clearUserData();
    // await _cacheService.clearUserCache();
  }

  // _generateUniqueFriendCode method removed
}

// Result class for better error handling
class DeleteAccountResult {
  final bool success;
  final String? error;
  final bool requiresReauth;
  final bool userNotFound;
  
  DeleteAccountResult._({
    required this.success,
    this.error,
    this.requiresReauth = false,
    this.userNotFound = false,
  });
  
  factory DeleteAccountResult.success() => DeleteAccountResult._(success: true);
  factory DeleteAccountResult.error(String error) => DeleteAccountResult._(success: false, error: error);
  factory DeleteAccountResult.requiresReauth() => DeleteAccountResult._(success: false, requiresReauth: true);
  factory DeleteAccountResult.userNotFound() => DeleteAccountResult._(success: false, userNotFound: true);
}
