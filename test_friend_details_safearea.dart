import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/screens/friends/friend_details_screen.dart';

void main() {
  runApp(const FriendDetailsSafeAreaTestApp());
}

class FriendDetailsSafeAreaTestApp extends StatelessWidget {
  const FriendDetailsSafeAreaTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Friend Details SafeArea Test',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const FriendDetailsSafeAreaTestScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class FriendDetailsSafeAreaTestScreen extends StatelessWidget {
  const FriendDetailsSafeAreaTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const FriendDetailsScreen(
        friendId: 'test_friend_id',
        friendName: 'Test Friend',
      ),
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