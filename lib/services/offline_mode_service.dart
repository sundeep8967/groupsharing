import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Offline mode service for handling network connectivity and data caching
class OfflineModeService extends ChangeNotifier {
  static const String _tag = 'OfflineModeService';
  
  // Singleton instance
  static OfflineModeService? _instance;
  static OfflineModeService get instance => _instance ??= OfflineModeService._();
  
  OfflineModeService._();
  
  // Connectivity state
  bool _isOnline = true;
  bool _hasInternetAccess = true;
  ConnectivityResult _connectionType = ConnectivityResult.none;
  
  // Subscriptions
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _internetCheckTimer;
  
  // Offline data cache
  final Map<String, CachedData> _cache = {};
  final List<PendingOperation> _pendingOperations = [];
  
  // Getters
  bool get isOnline => _isOnline && _hasInternetAccess;
  bool get isOffline => !isOnline;
  ConnectivityResult get connectionType => _connectionType;
  List<PendingOperation> get pendingOperations => List.unmodifiable(_pendingOperations);
  
  /// Initialize offline mode service
  Future<void> initialize() async {
    try {
      developer.log('[$_tag] Initializing offline mode service');
      
      // Check initial connectivity
      final connectivity = Connectivity();
      _connectionType = await connectivity.checkConnectivity();
      _isOnline = _connectionType != ConnectivityResult.none;
      
      // Start listening to connectivity changes
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      
      // Start periodic internet access check
      _startInternetAccessCheck();
      
      // Load cached data and pending operations
      await _loadCachedData();
      await _loadPendingOperations();
      
      developer.log('[$_tag] Offline mode service initialized. Online: $isOnline');
      
    } catch (e) {
      developer.log('[$_tag] Error initializing offline mode service: $e');
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetCheckTimer?.cancel();
    super.dispose();
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) async {
    developer.log('[$_tag] Connectivity changed: $result');
    
    final wasOnline = _isOnline;
    _connectionType = result;
    _isOnline = result != ConnectivityResult.none;
    
    if (_isOnline) {
      // Check actual internet access
      await _checkInternetAccess();
      
      // If we just came online, process pending operations
      if (!wasOnline && isOnline) {
        _processPendingOperations();
      }
    } else {
      _hasInternetAccess = false;
    }
    
    notifyListeners();
  }
  
  /// Check actual internet access (not just connectivity)
  Future<void> _checkInternetAccess() async {
    try {
      // Simple HTTP request to check internet access
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://www.google.com'));
      request.headers.set('User-Agent', 'GroupSharing/1.0');
      
      final response = await request.close().timeout(const Duration(seconds: 5));
      _hasInternetAccess = response.statusCode == 200;
      
      client.close();
      
    } catch (e) {
      _hasInternetAccess = false;
      developer.log('[$_tag] Internet access check failed: $e');
    }
  }
  
  /// Start periodic internet access check
  void _startInternetAccessCheck() {
    _internetCheckTimer?.cancel();
    _internetCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isOnline) {
        _checkInternetAccess().then((_) => notifyListeners());
      }
    });
  }
  
  /// Cache data for offline access
  Future<void> cacheData(String key, dynamic data, {Duration? expiry}) async {
    try {
      final cachedData = CachedData(
        key: key,
        data: data,
        timestamp: DateTime.now(),
        expiry: expiry != null ? DateTime.now().add(expiry) : null,
      );
      
      _cache[key] = cachedData;
      await _saveCachedData();
      
      developer.log('[$_tag] Data cached: $key');
      
    } catch (e) {
      developer.log('[$_tag] Error caching data: $e');
    }
  }
  
  /// Get cached data
  T? getCachedData<T>(String key) {
    try {
      final cachedData = _cache[key];
      
      if (cachedData == null) return null;
      
      // Check if data has expired
      if (cachedData.expiry != null && DateTime.now().isAfter(cachedData.expiry!)) {
        _cache.remove(key);
        _saveCachedData();
        return null;
      }
      
      return cachedData.data as T?;
      
    } catch (e) {
      developer.log('[$_tag] Error getting cached data: $e');
      return null;
    }
  }
  
  /// Add operation to pending queue for when online
  Future<void> addPendingOperation(PendingOperation operation) async {
    try {
      _pendingOperations.add(operation);
      await _savePendingOperations();
      
      developer.log('[$_tag] Added pending operation: ${operation.type}');
      
      // If we're online, try to process immediately
      if (isOnline) {
        _processPendingOperations();
      }
      
    } catch (e) {
      developer.log('[$_tag] Error adding pending operation: $e');
    }
  }
  
  /// Process all pending operations
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty || !isOnline) return;
    
    developer.log('[$_tag] Processing ${_pendingOperations.length} pending operations');
    
    final operationsToProcess = List<PendingOperation>.from(_pendingOperations);
    _pendingOperations.clear();
    
    for (final operation in operationsToProcess) {
      try {
        await _executeOperation(operation);
        developer.log('[$_tag] Successfully executed pending operation: ${operation.type}');
        
      } catch (e) {
        developer.log('[$_tag] Failed to execute pending operation: ${operation.type}, error: $e');
        
        // Re-add to pending if it's a retryable error
        if (_isRetryableError(e)) {
          _pendingOperations.add(operation);
        }
      }
    }
    
    await _savePendingOperations();
    notifyListeners();
  }
  
  /// Execute a pending operation
  Future<void> _executeOperation(PendingOperation operation) async {
    switch (operation.type) {
      case OperationType.locationUpdate:
        await _executeLocationUpdate(operation);
        break;
      case OperationType.friendRequest:
        await _executeFriendRequest(operation);
        break;
      case OperationType.statusUpdate:
        await _executeStatusUpdate(operation);
        break;
    }
  }
  
  /// Execute location update operation
  Future<void> _executeLocationUpdate(PendingOperation operation) async {
    // Implement location update logic
    developer.log('[$_tag] Executing location update operation');
  }
  
  /// Execute friend request operation
  Future<void> _executeFriendRequest(PendingOperation operation) async {
    // Implement friend request logic
    developer.log('[$_tag] Executing friend request operation');
  }
  
  /// Execute status update operation
  Future<void> _executeStatusUpdate(PendingOperation operation) async {
    // Implement status update logic
    developer.log('[$_tag] Executing status update operation');
  }
  
  /// Check if error is retryable
  bool _isRetryableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
           errorStr.contains('timeout') ||
           errorStr.contains('connection');
  }
  
  /// Save cached data to persistent storage
  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = _cache.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString('offline_cache', jsonEncode(cacheJson));
      
    } catch (e) {
      developer.log('[$_tag] Error saving cached data: $e');
    }
  }
  
  /// Load cached data from persistent storage
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('offline_cache');
      
      if (cacheString != null) {
        final cacheJson = jsonDecode(cacheString) as Map<String, dynamic>;
        _cache.clear();
        
        for (final entry in cacheJson.entries) {
          _cache[entry.key] = CachedData.fromJson(entry.value);
        }
        
        developer.log('[$_tag] Loaded ${_cache.length} cached items');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error loading cached data: $e');
    }
  }
  
  /// Save pending operations to persistent storage
  Future<void> _savePendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsJson = _pendingOperations.map((op) => op.toJson()).toList();
      await prefs.setString('pending_operations', jsonEncode(operationsJson));
      
    } catch (e) {
      developer.log('[$_tag] Error saving pending operations: $e');
    }
  }
  
  /// Load pending operations from persistent storage
  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsString = prefs.getString('pending_operations');
      
      if (operationsString != null) {
        final operationsJson = jsonDecode(operationsString) as List<dynamic>;
        _pendingOperations.clear();
        
        for (final opJson in operationsJson) {
          _pendingOperations.add(PendingOperation.fromJson(opJson));
        }
        
        developer.log('[$_tag] Loaded ${_pendingOperations.length} pending operations');
      }
      
    } catch (e) {
      developer.log('[$_tag] Error loading pending operations: $e');
    }
  }
  
  /// Clear all cached data
  Future<void> clearCache() async {
    _cache.clear();
    await _saveCachedData();
    developer.log('[$_tag] Cache cleared');
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int validCount = 0;
    
    for (final data in _cache.values) {
      if (data.expiry != null && now.isAfter(data.expiry!)) {
        expiredCount++;
      } else {
        validCount++;
      }
    }
    
    return {
      'totalItems': _cache.length,
      'validItems': validCount,
      'expiredItems': expiredCount,
      'pendingOperations': _pendingOperations.length,
    };
  }
}

/// Cached data model
class CachedData {
  final String key;
  final dynamic data;
  final DateTime timestamp;
  final DateTime? expiry;
  
  CachedData({
    required this.key,
    required this.data,
    required this.timestamp,
    this.expiry,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'expiry': expiry?.toIso8601String(),
    };
  }
  
  factory CachedData.fromJson(Map<String, dynamic> json) {
    return CachedData(
      key: json['key'],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      expiry: json['expiry'] != null ? DateTime.parse(json['expiry']) : null,
    );
  }
}

/// Pending operation model
class PendingOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  
  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }
  
  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: OperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

enum OperationType {
  locationUpdate,
  friendRequest,
  statusUpdate,
}

/// Extension for easy offline handling
extension OfflineAware<T> on Future<T> {
  Future<T> withOfflineSupport({
    required String cacheKey,
    Duration? cacheExpiry,
    T? fallbackValue,
  }) async {
    final offlineService = OfflineModeService.instance;
    
    try {
      if (offlineService.isOnline) {
        final result = await this;
        // Cache the result for offline use
        await offlineService.cacheData(cacheKey, result, expiry: cacheExpiry);
        return result;
      } else {
        // Try to get from cache
        final cachedResult = offlineService.getCachedData<T>(cacheKey);
        if (cachedResult != null) {
          return cachedResult;
        } else if (fallbackValue != null) {
          return fallbackValue;
        } else {
          throw OfflineException('No cached data available and device is offline');
        }
      }
    } catch (e) {
      // If online operation fails, try cache
      final cachedResult = offlineService.getCachedData<T>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
      throw e;
    }
  }
}

class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  
  @override
  String toString() => 'OfflineException: $message';
}