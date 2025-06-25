import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Very simple Firebase test - just tests if Firebase real-time listeners work at all
class FirebaseTestSimple extends StatefulWidget {
  const FirebaseTestSimple({super.key});

  @override
  State<FirebaseTestSimple> createState() => _FirebaseTestSimpleState();
}

class _FirebaseTestSimpleState extends State<FirebaseTestSimple> {
  int _updateCount = 0;
  String _lastUpdate = 'None';
  
  @override
  void initState() {
    super.initState();
    _startListening();
  }
  
  void _startListening() {
    // Listen to a simple test collection
    FirebaseFirestore.instance
        .collection('test_realtime')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _updateCount++;
        _lastUpdate = DateTime.now().toIso8601String().substring(11, 19);
      });
      debugPrint('FIREBASE_TEST: Update #$_updateCount at $_lastUpdate');
    });
  }
  
  Future<void> _triggerUpdate() async {
    try {
      await FirebaseFirestore.instance
          .collection('test_realtime')
          .doc('test')
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'counter': _updateCount,
        'message': 'Test update from app',
      });
      debugPrint('FIREBASE_TEST: Triggered update');
    } catch (e) {
      debugPrint('FIREBASE_TEST: Error - $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Firebase Updates Received: $_updateCount',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            Text('Last Update: $_lastUpdate'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _triggerUpdate,
              child: const Text('Trigger Firebase Update'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Instructions:\n'
              '1. Click "Trigger Firebase Update"\n'
              '2. You should see the counter increase\n'
              '3. If it doesn\'t, Firebase listeners aren\'t working',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}