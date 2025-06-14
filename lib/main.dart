import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:groupsharing/services/deep_link_service.dart';
import 'package:groupsharing/models/map_marker.dart';
import 'package:groupsharing/widgets/modern_map.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FMTCObjectBoxBackend().initialise();
  } catch (error, stackTrace) {
    // Optionally log or handle FMTC initialization errors
  }
  await Firebase.initializeApp();
  
  // Initialize deep links
  DeepLinkService.initDeepLinks();
  
  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  
  runApp(MyApp(isOnboardingComplete: isOnboardingComplete));
}

class MyApp extends StatelessWidget {
  final bool isOnboardingComplete;
  
  const MyApp({super.key, required this.isOnboardingComplete});

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
            if (!isOnboardingComplete) {
              return const OnboardingScreen();
            }
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
                    point: locationProvider.currentLocation!, // Default to current location until we implement real-time updates
                    label: 'User: $userId',
                    // Additional user details can be added here
                  ))
              .toSet();

          return Column(
            children: [
              Expanded(
                child: ModernMap(
                  initialPosition: locationProvider.currentLocation!,
                  markers: markers,
                  userLocation: locationProvider.currentLocation!,
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
