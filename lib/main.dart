import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/geofence_service_helper.dart';
import 'services/fcm_service.dart';
import 'package:groupsharing/services/deep_link_service.dart';
import 'package:groupsharing/models/map_marker.dart';
import 'package:groupsharing/widgets/modern_map.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/comprehensive_permission_screen.dart';
import 'services/permission_manager.dart';
import 'services/comprehensive_permission_service.dart';
import 'services/life360_location_service.dart';
import 'screens/performance_monitor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system UI overlay style for better status bar visibility
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, // Transparent status bar
    statusBarIconBrightness: Brightness.dark, // Dark icons for light backgrounds
    statusBarBrightness: Brightness.light, // Light status bar for iOS
    systemNavigationBarColor: Colors.white, // Navigation bar color
    systemNavigationBarIconBrightness: Brightness.dark, // Dark navigation icons
  ));
  
  // FMTC initialization removed - not needed for core functionality
  // try {
  //   await FMTCObjectBoxBackend().initialise();
  // } catch (error) {
  //   // Optionally log or handle FMTC initialization errors
  // }
  await Firebase.initializeApp();
  
  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize FCM service
  await FCMService.initialize();
  
  // Initialize deep links
  DeepLinkService.initDeepLinks();
  
  // Initialize Life360-style location service
  await Life360LocationService.initialize();
  
  // Check if we need to restore location tracking
  final shouldRestore = await Life360LocationService.shouldRestoreTracking();
  if (shouldRestore) {
    final userId = await Life360LocationService.getRestoreUserId();
    if (userId != null) {
      debugPrint('Restoring location tracking for user: ${userId.substring(0, 8)}');
      // The actual restoration will happen when the user logs in
    }
  }
  
  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(MyApp(isOnboardingComplete: isOnboardingComplete));
}

class MyApp extends StatefulWidget {
  final bool isOnboardingComplete;
  
  const MyApp({super.key, required this.isOnboardingComplete});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  LocationProvider? _locationProvider;
  bool _permissionsChecked = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }
  
  Future<void> _checkPermissions() async {
    try {
      // Use comprehensive permission service for thorough checking
      final granted = ComprehensivePermissionService.allPermissionsGranted;
      
      // If not granted, check detailed status
      if (!granted) {
        final status = await ComprehensivePermissionService.getDetailedPermissionStatus();
        final allGranted = status['allGranted'] ?? false;
        
        setState(() {
          _permissionsChecked = true;
          _permissionsGranted = allGranted;
        });
      } else {
        setState(() {
          _permissionsChecked = true;
          _permissionsGranted = true;
        });
      }
    } catch (e) {
      setState(() {
        _permissionsChecked = true;
        _permissionsGranted = false;
      });
    }
  }
  
  void _onPermissionsGranted() {
    setState(() {
      _permissionsGranted = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.detached:
        // App is being terminated - clean up user data
        _handleAppTermination();
        break;
      case AppLifecycleState.paused:
        // App is paused but not terminated
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App is resumed
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is inactive
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  void _handleAppTermination() {
    debugPrint('=== APP TERMINATION DETECTED ===');
    // Clean up Life360 service when app is being terminated/uninstalled
    Life360LocationService.cleanup();
    _locationProvider?.stopTracking();
  }

  void _handleAppPaused() {
    debugPrint('=== APP PAUSED ===');
    // App is paused but not terminated - no cleanup needed
  }

  void _handleAppResumed() {
    debugPrint('=== APP RESUMED ===');
    // App is resumed - reinitialize if needed
    _locationProvider?.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final locationProvider = LocationProvider();
            // Store reference for lifecycle management
            _locationProvider = locationProvider;
            // Initialize the provider with saved state
            locationProvider.initialize();
            return locationProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Location Sharing',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
        ),
        home: _buildHome(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/performance-monitor': (context) => const PerformanceMonitorScreen(),
        },
      ),
    );
  }
  
  Widget _buildHome() {
    // Show loading while checking permissions
    if (!_permissionsChecked) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }
    
    // Show comprehensive permission screen if permissions not granted
    if (!_permissionsGranted) {
      return ComprehensivePermissionScreen(
        onPermissionsGranted: _onPermissionsGranted,
      );
    }
    
    // Show normal app flow if permissions are granted
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!widget.isOnboardingComplete) {
          return const OnboardingScreen();
        }
        return auth.isAuthenticated
            ? const MainScreen()
            : const LoginScreen();
      },
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
        // Initialise and start geofencing for this user
        GeofenceHelper.initialize(authProvider.user!.uid).then((_) => GeofenceHelper.start());
        locationProvider.startTracking(authProvider.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    // Removed stopTracking from here to avoid calling provider after signOut
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
              // Stop services before sign-out
              Provider.of<LocationProvider>(context, listen: false).stopTracking();
              GeofenceHelper.stop();
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
          final markers = locationProvider.nearbyUsers.entries
              .map((entry) => MapMarker(
                    id: entry.key,
                    point: locationProvider.currentLocation!, // Default to current location until we implement real-time updates
                    label: 'User: ${entry.key}',
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
                      color: Colors.black.withValues(alpha: 0.1),
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
