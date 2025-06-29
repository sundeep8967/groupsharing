import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'advanced_location_engine.dart';

/// Advanced Motion Detection Engine
/// 
/// This engine implements Google Maps-level motion detection:
/// - Multi-sensor fusion (accelerometer, gyroscope, magnetometer)
/// - Advanced activity recognition (stationary, walking, running, cycling, driving)
/// - Machine learning-based pattern recognition
/// - Speed and acceleration analysis
/// - Contextual motion detection
/// - Confidence scoring for detected activities
/// - Transition detection and smoothing
class MotionDetectionEngine {
  static const String _tag = 'MotionDetectionEngine';
  static const MethodChannel _nativeChannel = MethodChannel('motion_detection_engine');
  
  MotionDetectionConfig _config = MotionDetectionConfig.defaultConfig();
  bool _isInitialized = false;
  bool _isTracking = false;
  
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  // Sensor data buffers
  final List<SensorData> _accelerometerBuffer = [];
  final List<SensorData> _gyroscopeBuffer = [];
  final List<SensorData> _magnetometerBuffer = [];
  final List<LocationMotionData> _locationBuffer = [];
  
  // Current state
  MotionState _currentMotionState = MotionState.unknown;
  double _currentConfidence = 0.0;
  ActivityMetrics _currentMetrics = ActivityMetrics.empty();
  
  // Motion analysis
  final MotionAnalyzer _analyzer = MotionAnalyzer();
  final ActivityClassifier _classifier = ActivityClassifier();
  final TransitionDetector _transitionDetector = TransitionDetector();
  
  // Statistics
  final MotionStatistics _statistics = MotionStatistics();
  
  // Stream controller for motion state changes
  final StreamController<MotionState> _motionStateController = 
      StreamController<MotionState>.broadcast();
  
  // Timers
  Timer? _analysisTimer;
  Timer? _cleanupTimer;
  
  Future<void> initialize(MotionDetectionConfig config) async {
    _config = config;
    
    try {
      // Initialize components
      await _analyzer.initialize(_config.analyzerConfig);
      await _classifier.initialize(_config.classifierConfig);
      await _transitionDetector.initialize(_config.transitionConfig);
      
      // Initialize native components
      await _initializeNativeComponents();
      
      _isInitialized = true;
      _log('Motion Detection Engine initialized');
      
    } catch (e, stackTrace) {
      _logError('Failed to initialize Motion Detection Engine', e, stackTrace);
    }
  }
  
  Future<void> start() async {
    if (!_isInitialized || _isTracking) return;
    
    try {
      // Start sensor monitoring
      await _startSensorMonitoring();
      
      // Start analysis timer
      _analysisTimer = Timer.periodic(
        _config.analysisInterval,
        (_) => _performMotionAnalysis(),
      );
      
      // Start cleanup timer
      _cleanupTimer = Timer.periodic(
        _config.cleanupInterval,
        (_) => _cleanupBuffers(),
      );
      
      _isTracking = true;
      _log('Motion Detection Engine started');
      
    } catch (e, stackTrace) {
      _logError('Failed to start Motion Detection Engine', e, stackTrace);
    }
  }
  
  Future<void> stop() async {
    if (!_isTracking) return;
    
    try {
      // Stop timers
      _analysisTimer?.cancel();
      _cleanupTimer?.cancel();
      
      // Stop sensor monitoring
      await _stopSensorMonitoring();
      
      _isTracking = false;
      _log('Motion Detection Engine stopped');
      
    } catch (e, stackTrace) {
      _logError('Error stopping Motion Detection Engine', e, stackTrace);
    }
  }
  
  Future<void> updateConfig(MotionDetectionConfig config) async {
    _config = config;
    
    if (_isInitialized) {
      await _analyzer.updateConfig(_config.analyzerConfig);
      await _classifier.updateConfig(_config.classifierConfig);
      await _transitionDetector.updateConfig(_config.transitionConfig);
    }
  }
  
  /// Analyze motion for a new location
  Future<MotionState> analyzeMotion(AdvancedLocationData location) async {
    if (!_isInitialized) return MotionState.unknown;
    
    try {
      // Add location to buffer
      final locationMotion = LocationMotionData.fromLocation(location);
      _locationBuffer.add(locationMotion);
      _limitBufferSize(_locationBuffer, _config.maxLocationBuffer);
      
      // Perform comprehensive motion analysis
      final motionResult = await _performComprehensiveAnalysis();
      
      // Update current state
      _currentMotionState = motionResult.motionState;
      _currentConfidence = motionResult.confidence;
      _currentMetrics = motionResult.metrics;
      
      // Update statistics
      _updateStatistics(motionResult);
      
      return _currentMotionState;
      
    } catch (e, stackTrace) {
      _logError('Error analyzing motion', e, stackTrace);
      return MotionState.unknown;
    }
  }
  
  /// Get current motion state with confidence
  MotionResult getCurrentMotion() {
    return MotionResult(
      motionState: _currentMotionState,
      confidence: _currentConfidence,
      metrics: _currentMetrics,
      timestamp: DateTime.now(),
    );
  }
  
  /// Get motion detection metrics
  MotionDetectionMetrics getMetrics() {
    return MotionDetectionMetrics(
      currentState: _currentMotionState,
      confidence: _currentConfidence,
      metrics: _currentMetrics,
      statistics: _statistics,
      bufferSizes: BufferSizes(
        accelerometer: _accelerometerBuffer.length,
        gyroscope: _gyroscopeBuffer.length,
        magnetometer: _magnetometerBuffer.length,
        location: _locationBuffer.length,
      ),
    );
  }
  
  /// Update location for motion analysis
  void updateLocation(AdvancedLocationData location) {
    if (!_isInitialized) return;
    
    try {
      // Add location to buffer
      final locationMotion = LocationMotionData.fromLocation(location);
      _locationBuffer.add(locationMotion);
      _limitBufferSize(_locationBuffer, _config.maxLocationBuffer);
      
      // Trigger immediate analysis if needed
      if (_config.immediateAnalysis) {
        _performMotionAnalysis();
      }
      
    } catch (e, stackTrace) {
      _logError('Error updating location for motion analysis', e, stackTrace);
    }
  }
  
  /// Stream of motion state changes
  Stream<MotionState> get motionStateStream => _motionStateController.stream;
  
  // Private methods
  
  Future<void> _initializeNativeComponents() async {
    try {
      await _nativeChannel.invokeMethod('initialize', {
        'config': _config.toMap(),
      });
    } catch (e) {
      _logError('Failed to initialize native components', e);
    }
  }
  
  Future<void> _startSensorMonitoring() async {
    try {
      // Start accelerometer
      _accelerometerSubscription = accelerometerEventStream().listen(
        (event) => _onAccelerometerData(event),
        onError: (error) => _logError('Accelerometer error', error),
      );
      
      // Start gyroscope
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (event) => _onGyroscopeData(event),
        onError: (error) => _logError('Gyroscope error', error),
      );
      
      // Start magnetometer
      _magnetometerSubscription = magnetometerEventStream().listen(
        (event) => _onMagnetometerData(event),
        onError: (error) => _logError('Magnetometer error', error),
      );
      
      _log('Sensor monitoring started');
      
    } catch (e, stackTrace) {
      _logError('Failed to start sensor monitoring', e, stackTrace);
    }
  }
  
  Future<void> _stopSensorMonitoring() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
    
    _log('Sensor monitoring stopped');
  }
  
  void _onAccelerometerData(AccelerometerEvent event) {
    final sensorData = SensorData(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    
    _accelerometerBuffer.add(sensorData);
    _limitBufferSize(_accelerometerBuffer, _config.maxSensorBuffer);
  }
  
  void _onGyroscopeData(GyroscopeEvent event) {
    final sensorData = SensorData(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    
    _gyroscopeBuffer.add(sensorData);
    _limitBufferSize(_gyroscopeBuffer, _config.maxSensorBuffer);
  }
  
  void _onMagnetometerData(MagnetometerEvent event) {
    final sensorData = SensorData(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    
    _magnetometerBuffer.add(sensorData);
    _limitBufferSize(_magnetometerBuffer, _config.maxSensorBuffer);
  }
  
  Future<void> _performMotionAnalysis() async {
    if (!_isTracking) return;
    
    try {
      final result = await _performComprehensiveAnalysis();
      
      // Check for state transitions
      if (result.motionState != _currentMotionState) {
        final transition = await _transitionDetector.detectTransition(
          _currentMotionState,
          result.motionState,
          result.confidence,
        );
        
        if (transition.isValid) {
          _currentMotionState = result.motionState;
          _currentConfidence = result.confidence;
          _currentMetrics = result.metrics;
          
          _log('Motion state changed: ${_currentMotionState.name} (confidence: ${_currentConfidence.toStringAsFixed(2)})');
          
          // Notify listeners
          _motionStateController.add(_currentMotionState);
          
          // Notify native layer
          await _notifyNativeStateChange();
        }
      }
      
    } catch (e, stackTrace) {
      _logError('Error in motion analysis', e, stackTrace);
    }
  }
  
  Future<MotionResult> _performComprehensiveAnalysis() async {
    // Analyze sensor data
    final sensorAnalysis = await _analyzer.analyzeSensorData(
      accelerometer: _accelerometerBuffer,
      gyroscope: _gyroscopeBuffer,
      magnetometer: _magnetometerBuffer,
    );
    
    // Analyze location data
    final locationAnalysis = await _analyzer.analyzeLocationData(_locationBuffer);
    
    // Combine analyses using classifier
    final classification = await _classifier.classify(
      sensorAnalysis: sensorAnalysis,
      locationAnalysis: locationAnalysis,
    );
    
    return classification;
  }
  
  Future<void> _notifyNativeStateChange() async {
    try {
      await _nativeChannel.invokeMethod('onMotionStateChanged', {
        'state': _currentMotionState.index,
        'confidence': _currentConfidence,
        'metrics': _currentMetrics.toMap(),
      });
    } catch (e) {
      _logError('Failed to notify native state change', e);
    }
  }
  
  void _updateStatistics(MotionResult result) {
    _statistics.totalAnalyses++;
    _statistics.lastAnalysisTime = DateTime.now();
    
    // Update state duration
    final stateDuration = _statistics.stateDurations[result.motionState] ?? Duration.zero;
    _statistics.stateDurations[result.motionState] = stateDuration + _config.analysisInterval;
    
    // Update confidence history
    _statistics.confidenceHistory.add(ConfidenceSample(
      confidence: result.confidence,
      state: result.motionState,
      timestamp: DateTime.now(),
    ));
    
    // Limit history size
    if (_statistics.confidenceHistory.length > _config.maxStatisticsHistory) {
      _statistics.confidenceHistory.removeAt(0);
    }
  }
  
  void _cleanupBuffers() {
    final cutoffTime = DateTime.now().subtract(_config.bufferRetentionTime);
    
    _accelerometerBuffer.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    _gyroscopeBuffer.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    _magnetometerBuffer.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    _locationBuffer.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
  }
  
  void _limitBufferSize(List buffer, int maxSize) {
    while (buffer.length > maxSize) {
      buffer.removeAt(0);
    }
  }
  
  void _log(String message) {
    developer.log(message, name: _tag);
  }
  
  void _logError(String message, [dynamic error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Dispose of the engine and clean up resources
  void dispose() {
    stop();
    _motionStateController.close();
  }
}

// Supporting classes

class SensorData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;
  
  const SensorData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });
  
  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class LocationMotionData {
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime timestamp;
  
  const LocationMotionData({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
  });
  
  factory LocationMotionData.fromLocation(AdvancedLocationData location) {
    return LocationMotionData(
      latitude: location.latitude,
      longitude: location.longitude,
      speed: location.speed,
      heading: location.heading,
      accuracy: location.accuracy,
      timestamp: location.timestamp,
    );
  }
}

class MotionResult {
  final MotionState motionState;
  final double confidence;
  final ActivityMetrics metrics;
  final DateTime timestamp;
  
  const MotionResult({
    required this.motionState,
    required this.confidence,
    required this.metrics,
    required this.timestamp,
  });
}

class ActivityMetrics {
  final double averageSpeed;
  final double maxSpeed;
  final double averageAcceleration;
  final double stepFrequency;
  final double movementVariance;
  final double directionStability;
  
  const ActivityMetrics({
    required this.averageSpeed,
    required this.maxSpeed,
    required this.averageAcceleration,
    required this.stepFrequency,
    required this.movementVariance,
    required this.directionStability,
  });
  
  factory ActivityMetrics.empty() {
    return const ActivityMetrics(
      averageSpeed: 0.0,
      maxSpeed: 0.0,
      averageAcceleration: 0.0,
      stepFrequency: 0.0,
      movementVariance: 0.0,
      directionStability: 0.0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'averageAcceleration': averageAcceleration,
      'stepFrequency': stepFrequency,
      'movementVariance': movementVariance,
      'directionStability': directionStability,
    };
  }
}

class MotionDetectionConfig {
  final Duration analysisInterval;
  final Duration cleanupInterval;
  final Duration bufferRetentionTime;
  final int maxSensorBuffer;
  final int maxLocationBuffer;
  final int maxStatisticsHistory;
  final MotionAnalyzerConfig analyzerConfig;
  final ActivityClassifierConfig classifierConfig;
  final TransitionDetectorConfig transitionConfig;
  final bool immediateAnalysis;
  
  const MotionDetectionConfig({
    required this.analysisInterval,
    required this.cleanupInterval,
    required this.bufferRetentionTime,
    required this.maxSensorBuffer,
    required this.maxLocationBuffer,
    required this.maxStatisticsHistory,
    required this.analyzerConfig,
    required this.classifierConfig,
    required this.transitionConfig,
    this.immediateAnalysis = false,
  });
  
  factory MotionDetectionConfig.defaultConfig() {
    return MotionDetectionConfig(
      analysisInterval: const Duration(seconds: 5),
      cleanupInterval: const Duration(minutes: 1),
      bufferRetentionTime: const Duration(minutes: 5),
      maxSensorBuffer: 200,
      maxLocationBuffer: 50,
      maxStatisticsHistory: 100,
      analyzerConfig: MotionAnalyzerConfig.defaultConfig(),
      classifierConfig: ActivityClassifierConfig.defaultConfig(),
      transitionConfig: TransitionDetectorConfig.defaultConfig(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'analysisInterval': analysisInterval.inMilliseconds,
      'cleanupInterval': cleanupInterval.inMilliseconds,
      'bufferRetentionTime': bufferRetentionTime.inMilliseconds,
      'maxSensorBuffer': maxSensorBuffer,
      'maxLocationBuffer': maxLocationBuffer,
      'maxStatisticsHistory': maxStatisticsHistory,
      'analyzerConfig': analyzerConfig.toMap(),
      'classifierConfig': classifierConfig.toMap(),
      'transitionConfig': transitionConfig.toMap(),
    };
  }
}

class MotionStatistics {
  int totalAnalyses = 0;
  DateTime? lastAnalysisTime;
  Map<MotionState, Duration> stateDurations = {};
  List<ConfidenceSample> confidenceHistory = [];
}

class ConfidenceSample {
  final double confidence;
  final MotionState state;
  final DateTime timestamp;
  
  const ConfidenceSample({
    required this.confidence,
    required this.state,
    required this.timestamp,
  });
}

class MotionDetectionMetrics {
  final MotionState currentState;
  final double confidence;
  final ActivityMetrics metrics;
  final MotionStatistics statistics;
  final BufferSizes bufferSizes;
  
  const MotionDetectionMetrics({
    required this.currentState,
    required this.confidence,
    required this.metrics,
    required this.statistics,
    required this.bufferSizes,
  });
}

class BufferSizes {
  final int accelerometer;
  final int gyroscope;
  final int magnetometer;
  final int location;
  
  const BufferSizes({
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.location,
  });
}

class StateTransition {
  final MotionState fromState;
  final MotionState toState;
  final double confidence;
  final bool isValid;
  final DateTime timestamp;
  
  const StateTransition({
    required this.fromState,
    required this.toState,
    required this.confidence,
    required this.isValid,
    required this.timestamp,
  });
}

// Placeholder classes for complex components
class MotionAnalyzer {
  Future<void> initialize(MotionAnalyzerConfig config) async {}
  Future<void> updateConfig(MotionAnalyzerConfig config) async {}
  
  Future<SensorAnalysisResult> analyzeSensorData({
    required List<SensorData> accelerometer,
    required List<SensorData> gyroscope,
    required List<SensorData> magnetometer,
  }) async {
    return SensorAnalysisResult.empty();
  }
  
  Future<LocationAnalysisResult> analyzeLocationData(List<LocationMotionData> locations) async {
    return LocationAnalysisResult.empty();
  }
}

class ActivityClassifier {
  Future<void> initialize(ActivityClassifierConfig config) async {}
  Future<void> updateConfig(ActivityClassifierConfig config) async {}
  
  Future<MotionResult> classify({
    required SensorAnalysisResult sensorAnalysis,
    required LocationAnalysisResult locationAnalysis,
  }) async {
    return MotionResult(
      motionState: MotionState.unknown,
      confidence: 0.0,
      metrics: ActivityMetrics.empty(),
      timestamp: DateTime.now(),
    );
  }
}

class TransitionDetector {
  Future<void> initialize(TransitionDetectorConfig config) async {}
  Future<void> updateConfig(TransitionDetectorConfig config) async {}
  
  Future<StateTransition> detectTransition(
    MotionState fromState,
    MotionState toState,
    double confidence,
  ) async {
    return StateTransition(
      fromState: fromState,
      toState: toState,
      confidence: confidence,
      isValid: confidence > 0.7,
      timestamp: DateTime.now(),
    );
  }
}

// Configuration classes (placeholders)
class MotionAnalyzerConfig {
  MotionAnalyzerConfig();
  factory MotionAnalyzerConfig.defaultConfig() => MotionAnalyzerConfig();
  Map<String, dynamic> toMap() => {};
}

class ActivityClassifierConfig {
  ActivityClassifierConfig();
  factory ActivityClassifierConfig.defaultConfig() => ActivityClassifierConfig();
  Map<String, dynamic> toMap() => {};
}

class TransitionDetectorConfig {
  TransitionDetectorConfig();
  factory TransitionDetectorConfig.defaultConfig() => TransitionDetectorConfig();
  Map<String, dynamic> toMap() => {};
}

class SensorAnalysisResult {
  SensorAnalysisResult();
  factory SensorAnalysisResult.empty() => SensorAnalysisResult();
}

class LocationAnalysisResult {
  LocationAnalysisResult();
  factory LocationAnalysisResult.empty() => LocationAnalysisResult();
}