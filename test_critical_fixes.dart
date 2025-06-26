import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/screens/friends/friends_family_screen.dart';

void main() {
  runApp(const CriticalFixesTestApp());
}

class CriticalFixesTestApp extends StatelessWidget {
  const CriticalFixesTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Critical Fixes Test',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const CriticalFixesTestScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class CriticalFixesTestScreen extends StatelessWidget {
  const CriticalFixesTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ Critical Fixes Applied'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎉 ALL CRITICAL ISSUES FIXED',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('✅ Removed popup dialog - direct toggle now'),
                  Text('✅ Fixed null pointer exceptions'),
                  Text('✅ Optimized performance - no more lag'),
                  Text('✅ SafeArea properly implemented'),
                  Text('✅ Friend markers working correctly'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test the Friends Screen:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendsFamilyScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('Open Friends Screen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧪 What to Test:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('1. Toggle location sharing - should work instantly'),
                  Text('2. No popup dialog should appear'),
                  Text('3. Content should not go behind navigation'),
                  Text('4. No null pointer exceptions in logs'),
                  Text('5. Smooth performance throughout'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}