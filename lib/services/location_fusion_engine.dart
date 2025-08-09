import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'advanced_location_engine.dart';

/// Advanced Location Fusion Engine
/// 
/// This engine implements Google Maps-level location fusion algorithms:
/// - Kalman filtering for smooth location tracking
/// - Multi-source location fusion (GPS, Network, Passive)
/// - Intelligent outlier detection and removal
/// - Predictive location interpolation
/// - Speed and heading smoothing
/// - Advanced noise reduction
class LocationFusionEngine {
  static const String _tag = 'LocationFusionEngine';
  
  FusionEngineConfig _config = FusionEngineConfig.defaultConfig();
  bool _isInitialized = false;
  
  // Kalman filter state
  KalmanFilter? _kalmanFilter;
  
  // Location buffers for fusion
  final List<AdvancedLocationData> _gpsBuffer = [];
  final List<AdvancedLocationData> _networkBuffer = [];
  final List<AdvancedLocationData> _passiveBuffer = [];
  final List<AdvancedLocationData> _fusedBuffer = [];
  
  // Statistics for quality assessment
  final LocationStatistics _statistics = LocationStatistics();
  
  Future<void> initialize(FusionEngineConfig config) async {
    _config = config;
    _kalmanFilter = KalmanFilter(
      processNoise: _config.processNoise,
      measurementNoise: _config.measurementNoise,
    );
    _isInitialized = true;
    _log('Location Fusion Engine initialized');
  }
  
  Future<void> start() async {
    if (!_isInitialized) return;
    _log('Location Fusion Engine started');
  }
  
  Future<void> stop() async {
    _clearBuffers();
    _log('Location Fusion Engine stopped');
  }
  
  Future<void> updateConfig(FusionEngineConfig config) async {
    _config = config;
    _kalmanFilter?.updateNoise(
      processNoise: _config.processNoise,
      measurementNoise: _config.measurementNoise,
    );
  }
  
  /// Main fusion method - combines multiple location sources
  Future<AdvancedLocationData?> fuseLocations(List<AdvancedLocationData> locations) async {
    if (!_isInitialized || locations.isEmpty) return null;
    
    try {
      // Categorize locations by source
      _categorizeLocations(locations);
      
      // Remove outliers
      final cleanedLocations = _removeOutliers(locations);
      if (cleanedLocations.isEmpty) return null;
      
      // Apply Kalman filtering
      final kalmanFiltered = await _applyKalmanFilter(cleanedLocations);
      
      // Perform weighted fusion
      final fusedLocation = await _performWeightedFusion(kalmanFiltered);
      
      // Apply smoothing
      final smoothedLocation = await _applySmoothingFilters(fusedLocation);
      
      // Update statistics
      _updateStatistics(smoothedLocation);
      
      // Cache the result
      _fusedBuffer.add(smoothedLocation);
      _limitBufferSize(_fusedBuffer, _config.maxBufferSize);
      
      return smoothedLocation;
      
    } catch (e, stackTrace) {
      _logError('Error in location fusion', e, stackTrace);
      return null;
    }
  }
  
  /// Get predicted location based on current trajectory
  Future<AdvancedLocationData?> predictLocation(Duration futureTime) async {
    if (_fusedBuffer.length < 2) return null;
    
    try {
      final recent = _fusedBuffer.takeLast(math.min(5, _fusedBuffer.length)).toList();
      
      // Calculate velocity vector
      final velocity = _calculateVelocityVector(recent);
      if (velocity == null) return null;
      
      final lastLocation = recent.last;
      final futureSeconds = futureTime.inMilliseconds / 1000.0;
      
      // Predict position
      final predictedLat = lastLocation.latitude + (velocity.latVelocity * futureSeconds);
      final predictedLng = lastLocation.longitude + (velocity.lngVelocity * futureSeconds);
      
      return AdvancedLocationData(
        latitude: predictedLat,
        longitude: predictedLng,
        altitude: lastLocation.altitude,
        accuracy: (lastLocation.accuracy ?? 0) * 2, // Increase uncertainty
        speed: velocity.speed,
        heading: velocity.heading,
        timestamp: lastLocation.timestamp.add(futureTime),
        quality: LocationQuality.fair, // Predicted locations are fair quality
        motionState: lastLocation.motionState,
        metadata: {
          ...lastLocation.metadata,
          'predicted': true,
          'predictionTime': futureTime.inMilliseconds,
        },
      );
      
    } catch (e, stackTrace) {
      _logError('Error predicting location', e, stackTrace);
      return null;
    }
  }
  
  /// Get fusion quality metrics
  FusionQualityMetrics getQualityMetrics() {
    return FusionQualityMetrics(
      averageAccuracy: _statistics.averageAccuracy,
      locationCount: _statistics.locationCount,
      outlierRate: _statistics.outlierRate,
      kalmanGain: _kalmanFilter?.lastGain ?? 0.0,
      fusionConfidence: _calculateFusionConfidence(),
    );
  }
  
  // Private methods
  
  void _categorizeLocations(List<AdvancedLocationData> locations) {
    for (final location in locations) {
      final source = location.metadata['source'] as String? ?? 'gps';
      
      switch (source) {
        case 'gps':
          _gpsBuffer.add(location);
          _limitBufferSize(_gpsBuffer, _config.maxBufferSize);
          break;
        case 'network':
          _networkBuffer.add(location);
          _limitBufferSize(_networkBuffer, _config.maxBufferSize);
          break;
        case 'passive':
          _passiveBuffer.add(location);
          _limitBufferSize(_passiveBuffer, _config.maxBufferSize);
          break;
      }
    }
  }
  
  List<AdvancedLocationData> _removeOutliers(List<AdvancedLocationData> locations) {
    if (locations.length < 3) return locations;
    
    final cleaned = <AdvancedLocationData>[];
    
    for (final location in locations) {
      if (_isLocationValid(location)) {
        cleaned.add(location);
      } else {
        _statistics.outlierCount++;
      }
    }
    
    return cleaned;
  }
  
  bool _isLocationValid(AdvancedLocationData location) {
    // Check basic validity
    if (location.latitude.abs() > 90 || location.longitude.abs() > 180) {
      return false;
    }
    
    // Check accuracy threshold
    if ((location.accuracy ?? double.infinity) > _config.maxAccuracyThreshold) {
      return false;
    }
    
    // Check speed threshold (detect impossible speeds)
    if ((location.speed ?? 0) > _config.maxSpeedThreshold) {
      return false;
    }
    
    // Check distance from previous locations
    if (_fusedBuffer.isNotEmpty) {
      final lastLocation = _fusedBuffer.last;
      final distance = location.distanceTo(lastLocation);
      final timeDiff = location.timestamp.difference(lastLocation.timestamp).inSeconds;
      
      if (timeDiff > 0) {
        final impliedSpeed = distance / timeDiff;
        if (impliedSpeed > _config.maxSpeedThreshold) {
          return false;
        }
      }
    }
    
    return true;
  }
  
  Future<List<AdvancedLocationData>> _applyKalmanFilter(List<AdvancedLocationData> locations) async {
    if (_kalmanFilter == null) return locations;
    
    final filtered = <AdvancedLocationData>[];
    
    for (final location in locations) {
      final filteredPosition = _kalmanFilter!.update(
        LocationVector(
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy ?? 10.0,
          timestamp: location.timestamp,
        ),
      );
      
      final filteredLocation = location.copyWith(
        latitude: filteredPosition.latitude,
        longitude: filteredPosition.longitude,
        metadata: {
          ...location.metadata,
          'kalmanFiltered': true,
          'kalmanGain': _kalmanFilter!.lastGain,
        },
      );
      
      filtered.add(filteredLocation);
    }
    
    return filtered;
  }
  
  Future<AdvancedLocationData> _performWeightedFusion(List<AdvancedLocationData> locations) async {
    if (locations.length == 1) return locations.first;
    
    double totalWeight = 0.0;
    double weightedLat = 0.0;
    double weightedLng = 0.0;
    double weightedAlt = 0.0;
    double weightedSpeed = 0.0;
    double weightedHeading = 0.0;
    
    DateTime latestTimestamp = locations.first.timestamp;
    LocationQuality bestQuality = LocationQuality.poor;
    
    for (final location in locations) {
      final weight = _calculateLocationWeight(location);
      totalWeight += weight;
      
      weightedLat += location.latitude * weight;
      weightedLng += location.longitude * weight;
      weightedAlt += (location.altitude ?? 0) * weight;
      weightedSpeed += (location.speed ?? 0) * weight;
      weightedHeading += (location.heading ?? 0) * weight;
      
      if (location.timestamp.isAfter(latestTimestamp)) {
        latestTimestamp = location.timestamp;
      }
      
      if (location.quality.index > bestQuality.index) {
        bestQuality = location.quality;
      }
    }
    
    if (totalWeight == 0) return locations.first;
    
    return AdvancedLocationData(
      latitude: weightedLat / totalWeight,
      longitude: weightedLng / totalWeight,
      altitude: weightedAlt / totalWeight,
      speed: weightedSpeed / totalWeight,
      heading: weightedHeading / totalWeight,
      accuracy: _calculateFusedAccuracy(locations),
      timestamp: latestTimestamp,
      quality: bestQuality,
      motionState: locations.first.motionState,
      metadata: {
        'fused': true,
        'sourceCount': locations.length,
        'totalWeight': totalWeight,
        'fusionMethod': 'weighted',
      },
    );
  }
  
  double _calculateLocationWeight(AdvancedLocationData location) {
    double weight = 1.0;
    
    // Weight by accuracy (better accuracy = higher weight)
    final accuracy = location.accuracy ?? 100.0;
    weight *= math.exp(-accuracy / _config.accuracyWeightFactor);
    
    // Weight by age (newer = higher weight)
    final age = DateTime.now().difference(location.timestamp).inSeconds;
    weight *= math.exp(-age / _config.ageWeightFactor);
    
    // Weight by source type
    final source = location.metadata['source'] as String? ?? 'gps';
    switch (source) {
      case 'gps':
        weight *= _config.gpsWeight;
        break;
      case 'network':
        weight *= _config.networkWeight;
        break;
      case 'passive':
        weight *= _config.passiveWeight;
        break;
    }
    
    // Weight by quality
    weight *= (location.quality.index + 1) / LocationQuality.values.length;
    
    return weight;
  }
  
  double _calculateFusedAccuracy(List<AdvancedLocationData> locations) {
    if (locations.isEmpty) return 100.0;
    
    // Use weighted harmonic mean for accuracy fusion
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (final location in locations) {
      final accuracy = location.accuracy ?? 100.0;
      final weight = _calculateLocationWeight(location);
      
      weightedSum += weight / accuracy;
      totalWeight += weight;
    }
    
    return totalWeight / weightedSum;
  }
  
  Future<AdvancedLocationData> _applySmoothingFilters(AdvancedLocationData location) async {
    if (_fusedBuffer.isEmpty) return location;
    
    // Apply exponential smoothing for position
    final smoothingFactor = _config.positionSmoothingFactor;
    final lastLocation = _fusedBuffer.last;
    
    final smoothedLat = (1 - smoothingFactor) * lastLocation.latitude + 
                       smoothingFactor * location.latitude;
    final smoothedLng = (1 - smoothingFactor) * lastLocation.longitude + 
                       smoothingFactor * location.longitude;
    
    // Apply smoothing for speed and heading
    final smoothedSpeed = _smoothValue(
      location.speed ?? 0,
      lastLocation.speed ?? 0,
      _config.speedSmoothingFactor,
    );
    
    final smoothedHeading = _smoothHeading(
      location.heading ?? 0,
      lastLocation.heading ?? 0,
      _config.headingSmoothingFactor,
    );
    
    return location.copyWith(
      latitude: smoothedLat,
      longitude: smoothedLng,
      speed: smoothedSpeed,
      heading: smoothedHeading,
      metadata: {
        ...location.metadata,
        'smoothed': true,
        'smoothingFactor': smoothingFactor,
      },
    );
  }
  
  double _smoothValue(double newValue, double oldValue, double factor) {
    return (1 - factor) * oldValue + factor * newValue;
  }
  
  double _smoothHeading(double newHeading, double oldHeading, double factor) {
    // Handle heading wraparound (0-360 degrees)
    double diff = newHeading - oldHeading;
    
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    
    double smoothedHeading = oldHeading + factor * diff;
    
    // Normalize to 0-360 range
    if (smoothedHeading < 0) {
      smoothedHeading += 360;
    } else if (smoothedHeading >= 360) {
      smoothedHeading -= 360;
    }
    
    return smoothedHeading;
  }
  
  VelocityVector? _calculateVelocityVector(List<AdvancedLocationData> locations) {
    if (locations.length < 2) return null;
    
    double totalLatVelocity = 0.0;
    double totalLngVelocity = 0.0;
    double totalSpeed = 0.0;
    int validSamples = 0;
    
    for (int i = 1; i < locations.length; i++) {
      final current = locations[i];
      final previous = locations[i - 1];
      
      final timeDiff = current.timestamp.difference(previous.timestamp).inSeconds;
      if (timeDiff <= 0) continue;
      
      final latDiff = current.latitude - previous.latitude;
      final lngDiff = current.longitude - previous.longitude;
      
      totalLatVelocity += latDiff / timeDiff;
      totalLngVelocity += lngDiff / timeDiff;
      totalSpeed += current.speed ?? 0;
      validSamples++;
    }
    
    if (validSamples == 0) return null;
    
    final avgLatVelocity = totalLatVelocity / validSamples;
    final avgLngVelocity = totalLngVelocity / validSamples;
    final avgSpeed = totalSpeed / validSamples;
    
    // Calculate heading from velocity vector
    final heading = math.atan2(avgLngVelocity, avgLatVelocity) * 180 / math.pi;
    final normalizedHeading = (heading + 360) % 360;
    
    return VelocityVector(
      latVelocity: avgLatVelocity,
      lngVelocity: avgLngVelocity,
      speed: avgSpeed,
      heading: normalizedHeading,
    );
  }
  
  void _updateStatistics(AdvancedLocationData location) {
    _statistics.locationCount++;
    
    final accuracy = location.accuracy ?? 0;
    _statistics.totalAccuracy += accuracy;
    _statistics.averageAccuracy = _statistics.totalAccuracy / _statistics.locationCount;
    
    if (_statistics.locationCount > 0) {
      _statistics.outlierRate = _statistics.outlierCount / _statistics.locationCount;
    }
  }
  
  double _calculateFusionConfidence() {
    if (_statistics.locationCount == 0) return 0.0;
    
    double confidence = 1.0;
    
    // Reduce confidence based on outlier rate
    confidence *= (1.0 - _statistics.outlierRate);
    
    // Reduce confidence based on average accuracy
    confidence *= math.exp(-_statistics.averageAccuracy / 50.0);
    
    // Increase confidence based on sample count
    confidence *= math.min(1.0, _statistics.locationCount / 10.0);
    
    return math.max(0.0, math.min(1.0, confidence));
  }
  
  void _limitBufferSize(List<AdvancedLocationData> buffer, int maxSize) {
    while (buffer.length > maxSize) {
      buffer.removeAt(0);
    }
  }
  
  void _clearBuffers() {
    _gpsBuffer.clear();
    _networkBuffer.clear();
    _passiveBuffer.clear();
    _fusedBuffer.clear();
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
}

/// Kalman Filter for location smoothing
class KalmanFilter {
  double _processNoise;
  double _measurementNoise;
  
  // State variables
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _latitudeVariance = 1000.0;
  double _longitudeVariance = 1000.0;
  
  double _lastGain = 0.0;
  bool _isInitialized = false;
  
  KalmanFilter({
    required double processNoise,
    required double measurementNoise,
  }) : _processNoise = processNoise,
       _measurementNoise = measurementNoise;
  
  LocationVector update(LocationVector measurement) {
    if (!_isInitialized) {
      _latitude = measurement.latitude;
      _longitude = measurement.longitude;
      _latitudeVariance = measurement.accuracy * measurement.accuracy;
      _longitudeVariance = measurement.accuracy * measurement.accuracy;
      _isInitialized = true;
      return measurement;
    }
    
    // Prediction step
    _latitudeVariance += _processNoise;
    _longitudeVariance += _processNoise;
    
    // Update step for latitude
    final latGain = _latitudeVariance / (_latitudeVariance + _measurementNoise);
    _latitude += latGain * (measurement.latitude - _latitude);
    _latitudeVariance *= (1 - latGain);
    
    // Update step for longitude
    final lngGain = _longitudeVariance / (_longitudeVariance + _measurementNoise);
    _longitude += lngGain * (measurement.longitude - _longitude);
    _longitudeVariance *= (1 - lngGain);
    
    _lastGain = (latGain + lngGain) / 2;
    
    return LocationVector(
      latitude: _latitude,
      longitude: _longitude,
      accuracy: math.sqrt((_latitudeVariance + _longitudeVariance) / 2),
      timestamp: measurement.timestamp,
    );
  }
  
  void updateNoise({required double processNoise, required double measurementNoise}) {
    _processNoise = processNoise;
    _measurementNoise = measurementNoise;
  }
  
  double get lastGain => _lastGain;
}

/// Configuration for the Fusion Engine
class FusionEngineConfig {
  final double processNoise;
  final double measurementNoise;
  final int maxBufferSize;
  final double maxAccuracyThreshold;
  final double maxSpeedThreshold;
  final double positionSmoothingFactor;
  final double speedSmoothingFactor;
  final double headingSmoothingFactor;
  final double accuracyWeightFactor;
  final double ageWeightFactor;
  final double gpsWeight;
  final double networkWeight;
  final double passiveWeight;
  
  const FusionEngineConfig({
    required this.processNoise,
    required this.measurementNoise,
    required this.maxBufferSize,
    required this.maxAccuracyThreshold,
    required this.maxSpeedThreshold,
    required this.positionSmoothingFactor,
    required this.speedSmoothingFactor,
    required this.headingSmoothingFactor,
    required this.accuracyWeightFactor,
    required this.ageWeightFactor,
    required this.gpsWeight,
    required this.networkWeight,
    required this.passiveWeight,
  });
  
  factory FusionEngineConfig.defaultConfig() {
    return const FusionEngineConfig(
      processNoise: 1.0,
      measurementNoise: 10.0,
      maxBufferSize: 50,
      maxAccuracyThreshold: 200.0,
      maxSpeedThreshold: 100.0, // 100 m/s = 360 km/h
      positionSmoothingFactor: 0.3,
      speedSmoothingFactor: 0.5,
      headingSmoothingFactor: 0.4,
      accuracyWeightFactor: 30.0,
      ageWeightFactor: 60.0,
      gpsWeight: 1.0,
      networkWeight: 0.7,
      passiveWeight: 0.5,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'processNoise': processNoise,
      'measurementNoise': measurementNoise,
      'maxBufferSize': maxBufferSize,
      'maxAccuracyThreshold': maxAccuracyThreshold,
      'maxSpeedThreshold': maxSpeedThreshold,
      'positionSmoothingFactor': positionSmoothingFactor,
      'speedSmoothingFactor': speedSmoothingFactor,
      'headingSmoothingFactor': headingSmoothingFactor,
      'accuracyWeightFactor': accuracyWeightFactor,
      'ageWeightFactor': ageWeightFactor,
      'gpsWeight': gpsWeight,
      'networkWeight': networkWeight,
      'passiveWeight': passiveWeight,
    };
  }
}

/// Supporting data classes
class LocationVector {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  
  const LocationVector({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

class VelocityVector {
  final double latVelocity;
  final double lngVelocity;
  final double speed;
  final double heading;
  
  const VelocityVector({
    required this.latVelocity,
    required this.lngVelocity,
    required this.speed,
    required this.heading,
  });
}

class LocationStatistics {
  int locationCount = 0;
  int outlierCount = 0;
  double totalAccuracy = 0.0;
  double averageAccuracy = 0.0;
  double outlierRate = 0.0;
}

class FusionQualityMetrics {
  final double averageAccuracy;
  final int locationCount;
  final double outlierRate;
  final double kalmanGain;
  final double fusionConfidence;
  
  const FusionQualityMetrics({
    required this.averageAccuracy,
    required this.locationCount,
    required this.outlierRate,
    required this.kalmanGain,
    required this.fusionConfidence,
  });
}

extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}