import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

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
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        print('Writing user doc for \\${user.uid}');
        final docSnap = await userDoc.get();
        String? friendCode = docSnap.data()?['friendCode'];
        if (friendCode == null || friendCode.length != 6) {
          friendCode = await _generateUniqueFriendCode();
        }
        await userDoc.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'friendCode': friendCode,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('User doc written');
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

  Future<String> _generateUniqueFriendCode() async {
    final db = FirebaseFirestore.instance.collection('users');
    String code;
    bool exists = true;
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    do {
      code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
      final query = await db.where('friendCode', isEqualTo: code).limit(1).get();
      exists = query.docs.isNotEmpty;
    } while (exists);
    return code;
  }
}
