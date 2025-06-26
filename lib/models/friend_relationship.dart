import 'package:flutter/material.dart';
import 'friendship_model.dart';
import 'user_model.dart';

/// Model that combines user information with friendship category
class FriendRelationship {
  final UserModel user;
  final FriendshipCategory category;
  final String friendshipId; // The friendship document ID for updates
  
  FriendRelationship({
    required this.user,
    required this.category,
    required this.friendshipId,
  });
  
  /// Helper method to get category display name
  String get categoryDisplayName {
    switch (category) {
      case FriendshipCategory.friend:
        return 'Friend';
      case FriendshipCategory.family:
        return 'Family';
    }
  }
  
  /// Helper method to get category icon
  IconData get categoryIcon {
    switch (category) {
      case FriendshipCategory.friend:
        return Icons.people;
      case FriendshipCategory.family:
        return Icons.family_restroom;
    }
  }
}