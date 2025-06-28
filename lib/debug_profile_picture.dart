import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:groupsharing/providers/auth_provider.dart' as app_auth;
import 'package:cached_network_image/cached_network_image.dart';

/// Debug screen to identify profile picture issues
class DebugProfilePicture extends StatefulWidget {
  const DebugProfilePicture({super.key});

  @override
  State<DebugProfilePicture> createState() => _DebugProfilePictureState();
}

class _DebugProfilePictureState extends State<DebugProfilePicture> {
  Map<String, dynamic>? _firestoreData;
  User? _firebaseAuthUser;
  String? _currentUserId;
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _addLog(String message) {
    setState(() {
      _debugLogs.insert(0, '[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
      if (_debugLogs.length > 20) _debugLogs.removeLast();
    });
    print('PROFILE_DEBUG: $message');
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      _currentUserId = authProvider.user?.uid;
      _firebaseAuthUser = FirebaseAuth.instance.currentUser;

      _addLog('Current User ID: $_currentUserId');
      _addLog('Firebase Auth User ID: ${_firebaseAuthUser?.uid}');
      _addLog('Firebase Auth Photo URL: ${_firebaseAuthUser?.photoURL}');

      if (_currentUserId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();

        if (doc.exists) {
          _firestoreData = doc.data();
          _addLog('Firestore document exists: ${doc.exists}');
          _addLog('Firestore photoUrl: ${_firestoreData?['photoUrl']}');
          _addLog('Firestore displayName: ${_firestoreData?['displayName']}');
          _addLog('Firestore email: ${_firestoreData?['email']}');
        } else {
          _addLog('Firestore document does not exist!');
        }
      } else {
        _addLog('No current user ID found!');
      }

      setState(() {});
    } catch (e) {
      _addLog('Error loading user data: $e');
    }
  }

  Future<void> _clearCache() async {
    _addLog('Clearing image cache...');
    try {
      await CachedNetworkImage.evictFromCache(_firestoreData?['photoUrl'] ?? '');
      await CachedNetworkImage.evictFromCache(_firebaseAuthUser?.photoURL ?? '');
      _addLog('Cache cleared successfully');
      setState(() {});
    } catch (e) {
      _addLog('Error clearing cache: $e');
    }
  }

  Future<void> _refreshData() async {
    _addLog('Refreshing user data...');
    await _firebaseAuthUser?.reload();
    _firebaseAuthUser = FirebaseAuth.instance.currentUser;
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Profile Picture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCache,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Profile Picture Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Profile Picture',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Firestore Photo
                        Column(
                          children: [
                            const Text('From Firestore:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _firestoreData?['photoUrl'] != null
                                  ? CachedNetworkImageProvider(
                                      _firestoreData!['photoUrl'],
                                      cacheKey: 'debug_firestore_${_currentUserId}',
                                    )
                                  : null,
                              child: _firestoreData?['photoUrl'] == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _firestoreData?['photoUrl'] != null ? 'Has Photo' : 'No Photo',
                              style: TextStyle(
                                color: _firestoreData?['photoUrl'] != null ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        // Firebase Auth Photo
                        Column(
                          children: [
                            const Text('From Firebase Auth:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _firebaseAuthUser?.photoURL != null
                                  ? CachedNetworkImageProvider(
                                      _firebaseAuthUser!.photoURL!,
                                      cacheKey: 'debug_auth_${_currentUserId}',
                                    )
                                  : null,
                              child: _firebaseAuthUser?.photoURL == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _firebaseAuthUser?.photoURL != null ? 'Has Photo' : 'No Photo',
                              style: TextStyle(
                                color: _firebaseAuthUser?.photoURL != null ? Colors.green : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Data Comparison
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Comparison',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildDataRow('User ID (Auth Provider)', _currentUserId ?? 'NULL'),
                    _buildDataRow('User ID (Firebase Auth)', _firebaseAuthUser?.uid ?? 'NULL'),
                    const Divider(),
                    _buildDataRow('Photo URL (Firestore)', _firestoreData?['photoUrl'] ?? 'NULL'),
                    _buildDataRow('Photo URL (Firebase Auth)', _firebaseAuthUser?.photoURL ?? 'NULL'),
                    const Divider(),
                    _buildDataRow('Display Name (Firestore)', _firestoreData?['displayName'] ?? 'NULL'),
                    _buildDataRow('Display Name (Firebase Auth)', _firebaseAuthUser?.displayName ?? 'NULL'),
                    const Divider(),
                    _buildDataRow('Email (Firestore)', _firestoreData?['email'] ?? 'NULL'),
                    _buildDataRow('Email (Firebase Auth)', _firebaseAuthUser?.email ?? 'NULL'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Issue Analysis
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issue Analysis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ..._getIssueAnalysis().map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            issue['isError'] ? Icons.error : Icons.info,
                            color: issue['isError'] ? Colors.red : Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue['message'],
                              style: TextStyle(
                                color: issue['isError'] ? Colors.red : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debug Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Logs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _debugLogs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            _debugLogs[index],
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == 'NULL' ? Colors.red : Colors.black87,
                fontFamily: value.startsWith('http') ? 'monospace' : null,
                fontSize: value.startsWith('http') ? 10 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getIssueAnalysis() {
    List<Map<String, dynamic>> issues = [];

    // Check if user IDs match
    if (_currentUserId != _firebaseAuthUser?.uid) {
      issues.add({
        'isError': true,
        'message': 'User ID mismatch between Auth Provider and Firebase Auth!'
      });
    }

    // Check if photo URLs are different
    final firestorePhoto = _firestoreData?['photoUrl'];
    final authPhoto = _firebaseAuthUser?.photoURL;
    
    if (firestorePhoto != authPhoto) {
      issues.add({
        'isError': true,
        'message': 'Photo URLs are different between Firestore and Firebase Auth!'
      });
    }

    // Check if both are null
    if (firestorePhoto == null && authPhoto == null) {
      issues.add({
        'isError': false,
        'message': 'No profile picture set in either Firestore or Firebase Auth.'
      });
    }

    // Check if only one has photo
    if (firestorePhoto != null && authPhoto == null) {
      issues.add({
        'isError': false,
        'message': 'Profile picture exists in Firestore but not in Firebase Auth.'
      });
    }

    if (firestorePhoto == null && authPhoto != null) {
      issues.add({
        'isError': false,
        'message': 'Profile picture exists in Firebase Auth but not in Firestore.'
      });
    }

    if (issues.isEmpty) {
      issues.add({
        'isError': false,
        'message': 'No obvious issues detected. The problem might be with caching or image loading.'
      });
    }

    return issues;
  }
}