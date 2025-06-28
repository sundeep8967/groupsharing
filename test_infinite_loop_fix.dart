import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/location_provider.dart';
import 'lib/providers/auth_provider.dart' as app_auth;

/// Test script to verify the infinite loop fix
void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Infinite Loop Fix Test',
        home: const TestScreen(),
      ),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _buildCount = 0;
  
  @override
  Widget build(BuildContext context) {
    _buildCount++;
    print('Build count: $_buildCount');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Build Count: $_buildCount'),
      ),
      body: Consumer<LocationProvider>(
        builder: (context, locationProvider, _) {
          // This should NOT cause infinite rebuilds anymore
          if (locationProvider.currentLocation == null && !locationProvider.isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && locationProvider.currentLocation == null) {
                print('Requesting location (build: $_buildCount)');
                locationProvider.getCurrentLocationForMap();
              }
            });
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Build Count: $_buildCount'),
                const SizedBox(height: 20),
                Text('Status: ${locationProvider.status}'),
                const SizedBox(height: 20),
                Text('Location: ${locationProvider.currentLocation?.toString() ?? 'None'}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    locationProvider.getCurrentLocationForMap();
                  },
                  child: const Text('Get Location'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    locationProvider.setDemoLocation();
                  },
                  child: const Text('Set Demo Location'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}