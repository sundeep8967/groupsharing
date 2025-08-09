import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Comprehensive performance optimization utility
/// Handles battery optimization, network efficiency, and memory management
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  // Battery optimization
  final Battery _battery = Battery();
  BatteryState? _batteryState;
  int? _batteryLevel;
  Timer? _batteryMonitorTimer;
  
  // Network optimization
  final Connectivity _connectivity = Connectivity();
  ConnectivityResult? _connectionType;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Memory optimization
  final Queue<String> _memoryLog = Queue<String>();
  Timer? _memoryCleanupTimer;
  static const int _maxMemoryLogEntries = 100;
  
  // Performance metrics
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, Duration> _operationDurations = {};
  
  // Adaptive settings based on device performance
  bool _isLowPowerMode = false;
  bool _isSlowNetwork = false;
  final bool _isLowMemoryDevice = false; // Could be enhanced with device detection

  /// Initialize performance monitoring
  Future<void> initialize() async {
    _log('Initializing PerformanceOptimizer...');
    
    await _initializeBatteryMonitoring();
    await _initializeNetworkMonitoring();
    _initializeMemoryManagement();
    
    _log('PerformanceOptimizer initialized successfully');
  }

  /// Battery optimization initialization
  Future<void> _initializeBatteryMonitoring() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      
      _updatePowerMode();
      
      // Monitor battery changes every 30 seconds
      _batteryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _updateBatteryStatus();
      });
      
      _log('Battery monitoring initialized - Level: $_batteryLevel%, State: $_batteryState');
    } catch (e) {
      _log('Error initializing battery monitoring: $e');
    }
  }

  /// Network optimization initialization
  Future<void> _initializeNetworkMonitoring() async {
    try {
      _connectionType = await _connectivity.checkConnectivity();
      _updateNetworkSettings();
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        _connectionType = result;
        _updateNetworkSettings();
        _log('Network changed to: $result');
      });
      
      _log('Network monitoring initialized - Type: $_connectionType');
    } catch (e) {
      _log('Error initializing network monitoring: $e');
    }
  }

  /// Memory management initialization
  void _initializeMemoryManagement() {
    // Clean up memory every 5 minutes
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performMemoryCleanup();
    });
    
    _log('Memory management initialized');
  }

  /// Update battery status and adjust performance settings
  Future<void> _updateBatteryStatus() async {
    try {
      final previousLevel = _batteryLevel;
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      
      _updatePowerMode();
      
      // Log significant battery changes
      if (previousLevel != null && (_batteryLevel! - previousLevel).abs() >= 5) {
        _log('Battery level changed: $previousLevel% → $_batteryLevel%');
      }
    } catch (e) {
      _log('Error updating battery status: $e');
    }
  }

  /// Update power mode based on battery level and state
  void _updatePowerMode() {
    final wasLowPowerMode = _isLowPowerMode;
    
    // Enable low power mode if battery is low or device is not charging
    _isLowPowerMode = (_batteryLevel != null && _batteryLevel! < 20) ||
                      _batteryState == BatteryState.discharging;
    
    if (wasLowPowerMode != _isLowPowerMode) {
      _log('Power mode changed: ${_isLowPowerMode ? 'LOW POWER' : 'NORMAL'}');
    }
  }

  /// Update network settings based on connection type
  void _updateNetworkSettings() {
    final wasSlowNetwork = _isSlowNetwork;
    
    // Consider mobile networks as potentially slow
    _isSlowNetwork = _connectionType == ConnectivityResult.mobile ||
                     _connectionType == ConnectivityResult.none;
    
    if (wasSlowNetwork != _isSlowNetwork) {
      _log('Network mode changed: ${_isSlowNetwork ? 'SLOW/LIMITED' : 'FAST'}');
    }
  }

  /// Perform memory cleanup
  void _performMemoryCleanup() {
    // Clear old operation logs
    if (_operationDurations.length > 50) {
      final keysToRemove = _operationDurations.keys.take(_operationDurations.length - 25).toList();
      for (final key in keysToRemove) {
        _operationDurations.remove(key);
      }
    }
    
    // Clear old memory logs
    while (_memoryLog.length > _maxMemoryLogEntries) {
      _memoryLog.removeFirst();
    }
    
    // Force garbage collection in debug mode
    if (kDebugMode) {
      SystemChannels.platform.invokeMethod('System.gc');
    }
    
    _log('Memory cleanup performed');
  }

  /// Get optimized location update interval based on performance conditions
  Duration getOptimizedLocationInterval() {
    if (_isLowPowerMode) {
      return const Duration(seconds: 60); // 1 minute in low power mode
    } else if (_isSlowNetwork) {
      return const Duration(seconds: 30); // 30 seconds on slow network
    } else {
      return const Duration(seconds: 15); // 15 seconds on fast network
    }
  }

  /// Get optimized location accuracy based on performance conditions
  double getOptimizedLocationAccuracy() {
    if (_isLowPowerMode) {
      return 100.0; // Lower accuracy to save battery
    } else if (_isSlowNetwork) {
      return 50.0; // Medium accuracy on slow network
    } else {
      return 25.0; // High accuracy on fast network
    }
  }

  /// Get optimized map tile cache size based on device performance
  int getOptimizedMapCacheSize() {
    if (_isLowMemoryDevice || _isLowPowerMode) {
      return 50; // 50MB cache for low-end devices
    } else if (_isSlowNetwork) {
      return 100; // 100MB cache for slow networks
    } else {
      return 200; // 200MB cache for high-end devices
    }
  }

  /// Get optimized Firebase update frequency
  Duration getOptimizedFirebaseUpdateInterval() {
    if (_isLowPowerMode) {
      return const Duration(seconds: 30); // Less frequent updates
    } else if (_isSlowNetwork) {
      return const Duration(seconds: 20); // Medium frequency
    } else {
      return const Duration(seconds: 10); // High frequency
    }
  }

  /// Start performance tracking for an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  /// End performance tracking for an operation
  void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationDurations[operationName] = duration;
      _operationStartTimes.remove(operationName);
      
      if (duration.inMilliseconds > 1000) {
        _log('SLOW OPERATION: $operationName took ${duration.inMilliseconds}ms');
      }
    }
  }

  /// Get performance metrics for an operation
  Duration? getOperationDuration(String operationName) {
    return _operationDurations[operationName];
  }

  /// Get all performance metrics
  Map<String, Duration> getAllMetrics() {
    return Map.from(_operationDurations);
  }

  /// Check if device should use reduced functionality
  bool shouldUseReducedFunctionality() {
    return _isLowPowerMode || _isSlowNetwork || _isLowMemoryDevice;
  }

  /// Get optimized debounce duration for UI updates
  Duration getOptimizedDebounceInterval() {
    if (_isLowPowerMode) {
      return const Duration(milliseconds: 500); // Longer debounce to save battery
    } else {
      return const Duration(milliseconds: 100); // Standard debounce
    }
  }

  /// Get current performance status
  Map<String, dynamic> getPerformanceStatus() {
    return {
      'batteryLevel': _batteryLevel,
      'batteryState': _batteryState?.toString(),
      'connectionType': _connectionType?.toString(),
      'isLowPowerMode': _isLowPowerMode,
      'isSlowNetwork': _isSlowNetwork,
      'isLowMemoryDevice': _isLowMemoryDevice,
      'operationCount': _operationDurations.length,
      'memoryLogCount': _memoryLog.length,
    };
  }

  /// Log performance message
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] PERFORMANCE: $message';
    
    _memoryLog.add(logEntry);
    if (_memoryLog.length > _maxMemoryLogEntries) {
      _memoryLog.removeFirst();
    }
    
    debugPrint(logEntry);
  }

  /// Get performance logs
  List<String> getPerformanceLogs() {
    return _memoryLog.toList();
  }

  /// Dispose and cleanup
  void dispose() {
    _batteryMonitorTimer?.cancel();
    _connectivitySubscription?.cancel();
    _memoryCleanupTimer?.cancel();
    
    _operationStartTimes.clear();
    _operationDurations.clear();
    _memoryLog.clear();
    
    _log('PerformanceOptimizer disposed');
  }
}