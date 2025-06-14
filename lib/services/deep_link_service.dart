import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  static const String scheme = 'groupsharing';
  static const String host = 'addfriend';
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription? _sub;

  static Future<void> initDeepLinks() async {
    try {
      // Get the initial link if the app was opened with a deep link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      // Listen for links when the app is in the foreground
      _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      }, onError: (err) {
        debugPrint('Deep link error: $err');
      });
    } catch (e) {
      debugPrint('Error initializing deep links: $e');
    }
  }

  static Future<void> _handleDeepLink(Uri? uri) async {
    if (uri == null) return;
    
    debugPrint('Handling deep link: $uri');
    
    if (uri.scheme == scheme && uri.host == host) {
      final targetUserId = uri.queryParameters['userId'];
      if (targetUserId == null) return;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return; // User needs to be logged in
      
      // Prevent self-adding
      if (currentUser.uid == targetUserId) {
        debugPrint('Cannot send friend request to yourself');
        return;
      }
      
      // Check if users are already friends or if a request already exists
      final db = FirebaseFirestore.instance;
      
      // Check if users are already friends
      final userDoc = await db.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final friends = List<String>.from(userData?['friends'] ?? []);
        
        if (friends.contains(targetUserId)) {
          debugPrint('Already friends with user');
          return;
        }
      }
      
      // Check if request already exists
      final requestQuery = await db
          .collection('friend_requests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      if (requestQuery.docs.isNotEmpty) {
        debugPrint('Friend request already sent');
        return;
      }
      
      // Create friend request
      await db.collection('friend_requests').add({
        'from': currentUser.uid,
        'to': targetUserId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Friend request sent to $targetUserId');
    }
  }

  static String generateProfileLink(String userId) {
    return '$scheme://$host?userId=$userId';
  }

  static void dispose() {
    _sub?.cancel();
  }
}
