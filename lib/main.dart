import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_service.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/comprehensive_permission_screen.dart';
import 'screens/friends/friend_details_screen.dart';
import 'screens/profile/location_permissions_screen.dart';
import 'services/comprehensive_permission_service.dart';
import 'services/life360_location_service.dart';
import 'services/bulletproof_location_service.dart';
import 'services/comprehensive_location_fix_service.dart';
import 'services/persistent_foreground_notification_service.dart';
import 'services/battery_optimization_service.dart';
import 'services/location_service_starter.dart';
import 'screens/performance_monitor_screen.dart';
import 'screens/settings/background_activity_setup_screen.dart';
import 'services/persistent_location_service.dart';

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
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize FCM service
  await FCMService.initialize();
  
  // Deep links removed - were not being used by any UI elements
  
  // Initialize Persistent Foreground Notification Service
  debugPrint('=== INITIALIZING PERSISTENT FOREGROUND NOTIFICATION SERVICE ===');
  await PersistentForegroundNotificationService.initialize();
  
  // Initialize Comprehensive Location Fix Service (primary - includes all fixes)
  debugPrint('=== INITIALIZING COMPREHENSIVE LOCATION FIX SERVICE ===');
  await ComprehensiveLocationFixService.initialize();
  
  // Initialize Bulletproof Location Service (integrated into comprehensive service)
  debugPrint('=== INITIALIZING BULLETPROOF LOCATION SERVICE ===');
  await BulletproofLocationService.initialize();
  
  // Initialize Life360-style location service (fallback)
  debugPrint('=== INITIALIZING LIFE360 LOCATION SERVICE ===');
  await Life360LocationService.initialize();
  
  // AUTOMATICALLY CHECK AND REQUEST BATTERY OPTIMIZATION
  debugPrint('=== CHECKING BATTERY OPTIMIZATION ===');
  try {
    final isDisabled = await BatteryOptimizationService.isBatteryOptimizationDisabled();
    if (!isDisabled) {
      debugPrint('BATTERY: Optimization is enabled, will prompt user to disable it');
      // Note: The actual prompt will show when the app UI is ready
    } else {
      debugPrint('BATTERY: Optimization already disabled - perfect!');
    }
  } catch (e) {
    debugPrint('BATTERY: Error checking optimization status: $e');
  }
  
  // Check if we need to restore location tracking with comprehensive service
  debugPrint('=== CHECKING FOR STATE RESTORATION ===');
  final shouldRestore = await ComprehensiveLocationFixService.shouldRestoreTracking();
  if (shouldRestore) {
    final userId = await ComprehensiveLocationFixService.getRestoreUserId();
    if (userId != null) {
      debugPrint('COMPREHENSIVE: Restoring location tracking for user: ${userId.substring(0, 8)}');
      // Restore tracking with comprehensive service
      final restored = await ComprehensiveLocationFixService.restoreTrackingState();
      if (restored) {
        debugPrint('COMPREHENSIVE: State restoration successful');
        // Start persistent notification
        await PersistentForegroundNotificationService.startPersistentNotification(userId);
      } else {
        debugPrint('COMPREHENSIVE: State restoration failed, trying fallback');
        // Fallback to bulletproof service
        final bulletproofRestored = await BulletproofLocationService.restoreTrackingState();
        if (bulletproofRestored) {
          debugPrint('BULLETPROOF: Fallback restoration successful');
        }
      }
    }
  } else {
    debugPrint('NO PREVIOUS STATE: Starting fresh');
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
  bool _permissionsSetupComplete = false; // user completed the setup screen at least once
  bool _prefsLoaded = false; // wait until SharedPreferences is loaded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissionsSetupFlag();
    _checkPermissions();
  }

  Future<void> _loadPermissionsSetupFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _permissionsSetupComplete = prefs.getBool('permissions_setup_complete') ?? false;
        _prefsLoaded = true;
      });
    } catch (e) {
      setState(() {
        _permissionsSetupComplete = false;
        _prefsLoaded = true;
      });
    }
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
        
        // AUTOMATICALLY CHECK BATTERY OPTIMIZATION AFTER PERMISSIONS ARE GRANTED
        _checkBatteryOptimizationOnStartup();
      }
    } catch (e) {
      setState(() {
        _permissionsChecked = true;
        _permissionsGranted = false;
      });
    }
  }
  
  Future<void> _checkBatteryOptimizationOnStartup() async {
    // Wait a bit for the UI to be ready
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      try {
        await BatteryOptimizationService.checkAndPromptBatteryOptimization(context);
      } catch (e) {
        debugPrint('Error checking battery optimization on startup: $e');
      }
    }
  }
  
  void _onPermissionsGranted() {
    setState(() {
      _permissionsGranted = true;
      _permissionsSetupComplete = true;
    });
    // Persist the setup completion so we don't show the screen again
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('permissions_setup_complete', true);
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
        // App is being terminated - ensure background tracking continues
        _handleAppTermination();
        // Enter background throttling mode
        PersistentLocationService.setBackgroundMode(true);
        break;
      case AppLifecycleState.paused:
        // App is paused but not terminated
        _handleAppPaused();
        // Enter background throttling mode
        PersistentLocationService.setBackgroundMode(true);
        break;
      case AppLifecycleState.resumed:
        // App is resumed - restore state and check service health
        _handleAppResumed();
        // Exit background throttling mode
        PersistentLocationService.setBackgroundMode(false);
        break;
      case AppLifecycleState.inactive:
        // App is inactive
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        // Enter background throttling mode
        PersistentLocationService.setBackgroundMode(true);
        break;
    }
  }

  void _handleAppTermination() {
    debugPrint('=== APP TERMINATION DETECTED ===');
    // DON'T clean up location services - they should continue in background
    // Only clean up if user explicitly stops tracking
    debugPrint('Background location tracking should continue...');
  }

  void _handleAppPaused() {
    debugPrint('=== APP PAUSED ===');
    // App is paused but not terminated - ensure background tracking continues
    _ensureBackgroundTracking();
  }

  void _handleAppResumed() {
    debugPrint('=== APP RESUMED ===');
    // App is resumed - restore state and check service health
    _restoreStateOnResume();
  }
  
  Future<void> _ensureBackgroundTracking() async {
    try {
      // Check if bulletproof service is still running
      final isTracking = BulletproofLocationService.isTracking;
      if (isTracking) {
        debugPrint('BULLETPROOF: Background tracking is active');
      } else {
        debugPrint('BULLETPROOF: Background tracking not active, checking for restoration');
        await BulletproofLocationService.restoreTrackingState();
      }
    } catch (e) {
      debugPrint('Error ensuring background tracking: $e');
    }
  }
  
  Future<void> _restoreStateOnResume() async {
    try {
      debugPrint('=== RESTORING STATE ON RESUME ===');
      
      // First, try to restore bulletproof service state
      final bulletproofRestored = await BulletproofLocationService.restoreTrackingState();
      if (bulletproofRestored) {
        debugPrint('BULLETPROOF: State restored successfully on resume');
      } else {
        debugPrint('BULLETPROOF: No state to restore or restoration failed');
      }
      
      // Also reinitialize location provider
      _locationProvider?.initialize();
      
      // Check service health
      final isHealthy = await BulletproofLocationService.checkServiceHealth();
      debugPrint('BULLETPROOF: Service health check: $isHealthy');
      
    } catch (e) {
      debugPrint('Error restoring state on resume: $e');
    }
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
          '/location-permissions': (context) => const LocationPermissionsScreen(),
          '/background-activity-setup': (context) => const BackgroundActivitySetupScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes with arguments
          switch (settings.name) {
            case '/friend-details':
              final args = settings.arguments as Map<String, dynamic>?;
              final friendId = args?['friendId'] as String?;
              final friendName = args?['friendName'] as String? ?? 'Friend';
              if (friendId != null) {
                return MaterialPageRoute(
                  builder: (context) => FriendDetailsScreen(
                    friendId: friendId,
                    friendName: friendName,
                  ),
                );
              }
              break;
          }
          return null;
        },
      ),
    );
  }
  
  Widget _buildHome() {
    // Show loading until both prefs and permission checks are done
    if (!_prefsLoaded || !_permissionsChecked) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing app...'),
            ],
          ),
        ),
      );
    }
    // Always gate login behind the permission setup screen at least once
    // Show the comprehensive permission screen if the user hasn't completed setup yet
    if (!_permissionsSetupComplete) {
      return ComprehensivePermissionScreen(
        onPermissionsGranted: _onPermissionsGranted,
      );
    }
    // If setup was completed previously but permissions were revoked, show the screen again
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

// Background message handler for FCM
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Handling a background message: ${message.messageId}');
}