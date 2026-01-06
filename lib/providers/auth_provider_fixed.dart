import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service_fixed.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'dart:async';

/// Fixed AuthProvider with proper timeout and error handling
class AuthProviderFixed with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  // Timeout duration for login operations
  static const Duration _loginTimeout = Duration(seconds: 30);
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProviderFixed() {
    // Initialize with current user immediately to prevent login screen flash
    _user = FirebaseAuth.instance.currentUser;
    
    // Listen to auth state changes but don't interfere with manual navigation
    _authService.authStateChanges.listen((User? user) {
      if (_user?.uid != user?.uid) {
        _user = user;
        notifyListeners();
      }
    });
  }

  /// Simplified Google Sign-In with timeout and proper error handling
  Future<AuthResult> signInWithGoogle() async {
    try {
      developer.log('[AUTH_FIXED] Starting Google Sign-In...');
      
      _setLoading(true);
      _clearError();

      // Add timeout to prevent infinite loading
      final result = await _signInWithTimeout();
      
      if (result.success && _user != null) {
        developer.log('[AUTH_FIXED] Sign-in successful, initializing user data...');
        
        // Initialize user data in background (don't block navigation)
        _initializeUserDataInBackground(_user!);
        
        return AuthResult(success: true);
      } else {
        return result;
      }
      
    } catch (e) {
      developer.log('[AUTH_FIXED] Sign-in error: $e');
      
      String errorMessage = 'Sign-in failed';
      if (e.toString().contains('cancelled') || e.toString().contains('SIGN_IN_CANCELLED')) {
        errorMessage = 'SIGN_IN_CANCELLED';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Sign-in timed out. Please try again.';
      }
      
      _setError(errorMessage);
      return AuthResult(success: false, error: errorMessage);
      
    } finally {
      _setLoading(false);
    }
  }

  /// Sign-in with timeout to prevent infinite loading
  Future<AuthResult> _signInWithTimeout() async {
    try {
      // Use timeout to prevent infinite loading
      await _authService.signInWithGoogle().timeout(_loginTimeout);
      
      // Update user state
      _user = FirebaseAuth.instance.currentUser;
      
      if (_user != null) {
        developer.log('[AUTH_FIXED] Firebase user obtained: ${_user!.email}');
        return AuthResult(success: true);
      } else {
        return AuthResult(success: false, error: 'Authentication failed');
      }
      
    } on TimeoutException {
      developer.log('[AUTH_FIXED] Sign-in timed out');
      return AuthResult(success: false, error: 'Sign-in timed out. Please try again.');
      
    } on FirebaseAuthException catch (e) {
      developer.log('[AUTH_FIXED] Firebase auth error: ${e.code} - ${e.message}');
      
      if (e.code == 'sign_in_canceled') {
        return AuthResult(success: false, error: 'SIGN_IN_CANCELLED');
      }
      
      return AuthResult(success: false, error: e.message ?? 'Authentication failed');
      
    } catch (e) {
      developer.log('[AUTH_FIXED] Unexpected error: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Initialize user data in background (non-blocking)
  void _initializeUserDataInBackground(User user) {
    // Run in background without blocking navigation
    Future.microtask(() async {
      try {
        developer.log('[AUTH_FIXED] Initializing user data for: ${user.email}');
        
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final docSnap = await userDoc.get();
        
        Map<String, dynamic> userData = {
          'email': user.email?.toLowerCase(),
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (!docSnap.exists) {
          // New user - generate friend code
          final friendCode = await _authService.generateUniqueFriendCode();
          userData['friendCode'] = friendCode;
          userData['createdAt'] = FieldValue.serverTimestamp();
          developer.log('[AUTH_FIXED] Creating new user document with friend code: $friendCode');
        } else {
          // Existing user - check friend code
          final existingData = docSnap.data();
          final friendCode = existingData?['friendCode'];
          
          if (friendCode == null || friendCode.length != 6) {
            final newFriendCode = await _authService.generateUniqueFriendCode();
            userData['friendCode'] = newFriendCode;
            developer.log('[AUTH_FIXED] Generated new friend code for existing user: $newFriendCode');
          } else {
            userData['friendCode'] = friendCode;
            developer.log('[AUTH_FIXED] Using existing friend code: $friendCode');
          }
        }
        
        await userDoc.set(userData, SetOptions(merge: true));
        developer.log('[AUTH_FIXED] User data initialization completed');
        
      } catch (e) {
        developer.log('[AUTH_FIXED] Error initializing user data: $e');
        // Don't throw - this is background initialization
      }
    });
  }

  /// Sign out with proper cleanup
  Future<bool> signOut() async {
    try {
      _setLoading(true);
      _clearError();
      
      await _authService.signOut();
      _user = null;
      
      developer.log('[AUTH_FIXED] Sign out successful');
      return true;
      
    } catch (e) {
      developer.log('[AUTH_FIXED] Sign out error: $e');
      _setError('Sign out failed');
      return false;
      
    } finally {
      _setLoading(false);
    }
  }

  /// Reload current user
  Future<void> reloadUser() async {
    if (_user != null) {
      try {
        await _user!.reload();
        _user = FirebaseAuth.instance.currentUser;
        notifyListeners();
      } catch (e) {
        developer.log('[AUTH_FIXED] Error reloading user: $e');
      }
    }
  }

  /// Helper methods for state management
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    _setError(null);
  }

  /// Delete user account (placeholder - needs proper implementation)
  Future<DeleteAccountResult> deleteUserAccount() async {
    developer.log('[AUTH_FIXED] Account deletion not implemented yet');
    return DeleteAccountResult.error('Account deletion feature is not available');
  }
  
  /// Helper method to clear user data
  Future<void> _clearUserData() async {
    // Clear any cached user data, preferences, etc.
    // This can be expanded as needed
  }

  /// Force reset loading state (emergency method)
  void forceResetLoadingState() {
    developer.log('[AUTH_FIXED] Force resetting loading state');
    _setLoading(false);
    _clearError();
  }
}

/// Auth result class for better error handling
class AuthResult {
  final bool success;
  final String? error;

  AuthResult({required this.success, this.error});
}

/// Result class for account deletion operations
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
  
  factory DeleteAccountResult.requiresReauth() => DeleteAccountResult._(
    success: false,
    requiresReauth: true,
    error: 'Recent authentication required',
  );
  
  factory DeleteAccountResult.userNotFound() => DeleteAccountResult._(
    success: false,
    userNotFound: true,
    error: 'User not found',
  );
  
  factory DeleteAccountResult.error(String error) => DeleteAccountResult._(
    success: false,
    error: error,
  );
}