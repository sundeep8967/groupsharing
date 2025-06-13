import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'widgets/app_map_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Location Sharing',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isAuthenticated
                ? const MainScreen()
                : const LoginScreen();
          },
        ),
      ),
    );
  }
}

class LocationSharingPage extends StatefulWidget {
  const LocationSharingPage({super.key});

  @override
  State<LocationSharingPage> createState() => _LocationSharingPageState();
}

class _LocationSharingPageState extends State<LocationSharingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);

      if (authProvider.user != null) {
        locationProvider.startTracking(authProvider.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Sharing'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
          ),
        ],
      ),
      body: Consumer2<LocationProvider, AuthProvider>(
        builder: (context, locationProvider, authProvider, _) {
          if (locationProvider.currentLocation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    locationProvider.status,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (locationProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        locationProvider.error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (locationProvider.error != null)
                    ElevatedButton(
                      onPressed: () => locationProvider.startTracking(authProvider.user!.uid),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            );
          }

          // Convert nearby users to MapMarker objects
          final markers = locationProvider.nearbyUsers
              .map((userId) => MapMarker(
                    id: userId,
                    position: locationProvider.currentLocation!, // Default to current location until we implement real-time updates
                    title: 'User: $userId',
                    // Additional user details can be added here
                  ))
              .toSet();

          return Column(
            children: [
              Expanded(
                child: AppMapWidget(
                  initialPosition: locationProvider.currentLocation!,
                  markers: markers,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: locationProvider.isTracking
                    ? () => locationProvider.stopTracking()
                    : () => locationProvider.startTracking(authProvider.user!.uid),
                icon: Icon(
                  locationProvider.isTracking ? Icons.location_on : Icons.location_off,
                ),
                label: Text(
                  locationProvider.isTracking ? 'Stop Sharing' : 'Start Sharing',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nearby Users: ${locationProvider.nearbyUsers.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
