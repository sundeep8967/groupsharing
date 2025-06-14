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

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signInWithEmailAndPassword(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, String displayName) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.registerWithEmailAndPassword(
        email,
        password,
        displayName,
      );
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    if (_user != null) {
      await _user!.reload();
      // Re-fetch the user from FirebaseAuth instance to get the updated object.
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signInWithGoogle();

      // After successful sign-in, ensure friendCode is set and unique
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final docSnap = await userDoc.get();
      String? friendCode = docSnap.data()?['friendCode'];
      if (friendCode == null || friendCode.length != 6) {
        // Generate a unique 6-digit code
        friendCode = await _generateUniqueFriendCode();
        await userDoc.set({'friendCode': friendCode}, SetOptions(merge: true));
      }
    } finally {
      _isLoading = false;
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
