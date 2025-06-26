import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/screens/friends/friends_family_screen.dart';

void main() {
  runApp(const FriendsSafeAreaTestApp());
}

class FriendsSafeAreaTestApp extends StatelessWidget {
  const FriendsSafeAreaTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Friends SafeArea Test',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const FriendsSafeAreaTestScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class FriendsSafeAreaTestScreen extends StatelessWidget {
  const FriendsSafeAreaTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const FriendsFamilyScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_outlined),
            selectedIcon: Icon(Icons.person_add),
            label: 'Add',
          ),
        ],
      ),
    );
  }
}