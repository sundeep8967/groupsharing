import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending,
  accepted,
  rejected
}

class FriendshipModel {
  final String id; // Document ID
  final String from; // Sender UID
  final String to;   // Receiver UID
  final FriendshipStatus status;
  final DateTime timestamp; // Creation timestamp
  final DateTime? updatedAt; // Updated timestamp for status changes

  FriendshipModel({
    required this.id,
    required this.from,
    required this.to,
    required this.status,
    required this.timestamp,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      // 'id' is not part of the document data, it's the doc ID
      'from': from,
      'to': to,
      'status': status.toString(), // e.g., "FriendshipStatus.pending"
      'timestamp': Timestamp.fromDate(timestamp), // Convert DateTime to Firestore Timestamp
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory FriendshipModel.fromMap(Map<String, dynamic> map, String id) {
    return FriendshipModel(
      id: id,
      from: map['from'] as String,
      to: map['to'] as String,
      status: FriendshipStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => FriendshipStatus.pending, // Default if status is malformed
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
