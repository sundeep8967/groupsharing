/// Emergency contact model for Life360-style emergency features
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? userId; // If contact is also a user of the app
  final int priority; // 1 = highest priority
  final EmergencyContactType type;
  final bool isActive;
  final DateTime createdAt;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.userId,
    this.priority = 1,
    this.type = EmergencyContactType.family,
    this.isActive = true,
    required this.createdAt,
  });

  /// Create a copy with updated fields
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? userId,
    int? priority,
    EmergencyContactType? type,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'userId': userId,
      'priority': priority,
      'type': type.toString(),
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from map (Firestore)
  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      userId: map['userId'],
      priority: map['priority'] ?? 1,
      type: EmergencyContactType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => EmergencyContactType.family,
      ),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  /// Get contact type icon
  String get typeIcon {
    switch (type) {
      case EmergencyContactType.family:
        return '👨‍👩‍👧‍👦';
      case EmergencyContactType.friend:
        return '👥';
      case EmergencyContactType.medical:
        return '🏥';
      case EmergencyContactType.work:
        return '🏢';
      case EmergencyContactType.other:
        return '📞';
    }
  }

  /// Get contact type display name
  String get typeDisplayName {
    switch (type) {
      case EmergencyContactType.family:
        return 'Family';
      case EmergencyContactType.friend:
        return 'Friend';
      case EmergencyContactType.medical:
        return 'Medical';
      case EmergencyContactType.work:
        return 'Work';
      case EmergencyContactType.other:
        return 'Other';
    }
  }

  /// Get formatted phone number
  String get formattedPhoneNumber {
    if (phoneNumber.isEmpty) return '';
    
    // Basic phone number formatting (can be enhanced)
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return phoneNumber;
  }

  @override
  String toString() {
    return 'EmergencyContact(id: $id, name: $name, phoneNumber: $phoneNumber, '
           'type: $typeDisplayName, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is EmergencyContact &&
        other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}

/// Enum for emergency contact types
enum EmergencyContactType {
  family,
  friend,
  medical,
  work,
  other,
}