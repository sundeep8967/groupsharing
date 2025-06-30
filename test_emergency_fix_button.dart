import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;
import 'lib/providers/location_provider.dart';
import 'lib/screens/main/main_screen.dart';

/// Test script to verify emergency fix button functionality
void main() {
  runApp(const EmergencyFixButtonTestApp());
}

class EmergencyFixButtonTestApp extends StatelessWidget {
  const EmergencyFixButtonTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Emergency Fix Button Test',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}