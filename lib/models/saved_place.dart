import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPlace {
  final String id;
  final String name;
  final String address;
  final String icon;

  SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.icon,
  });

  factory SavedPlace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return SavedPlace(
      id: doc.id,
      name: data?['name'] ?? '',
      address: data?['address'] ?? '',
      icon: data?['icon'] ?? 'other',
    );
  }
}
