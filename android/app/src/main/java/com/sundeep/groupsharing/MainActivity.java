package com.sundeep.groupsharing;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_PERSISTENT_LOCATION = "persistent_location_service";
    private static final String CHANNEL_BACKGROUND_LOCATION = "background_location";
    private static final String CHANNEL_BATTERY = "com.sundeep.groupsharing/battery_optimization";
    private static final String CHANNEL_ANDROID_PERMISSIONS = "android_permissions";
    private static final String CHANNEL_DRIVING_DETECTION = "native_driving_detection";
    private static final String CHANNEL_EMERGENCY_SERVICE = "native_emergency_service";
    private static final String CHANNEL_GEOFENCE_SERVICE = "native_geofence_service";
    private static final int LOCATION_PERMISSION_REQUEST_CODE = 1001;
    private static final int BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE = 1002;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Persistent Location Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_PERSISTENT_LOCATION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startBackgroundLocationService":
                            handleStartBackgroundLocationService(call, result);
                            break;
                        case "stopBackgroundLocationService":
                            handleStopBackgroundLocationService(result);
                            break;
                        case "isServiceHealthy":
                            result.success(isLocationServiceHealthy());
                            break;
                        case "requestBackgroundLocationPermission":
                            requestBackgroundLocationPermission(result);
                            break;
                        case "registerBackgroundHandlers":
                            registerBackgroundHandlers(result);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Legacy Background Location Channel (for backward compatibility)
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_BACKGROUND_LOCATION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "start":
                            String userId = call.argument("userId");
                            if (userId != null) {
                                handleStartBackgroundLocationServiceLegacy(userId, result);
                            } else {
                                result.error("INVALID_ARGUMENT", "User ID is required", null);
                            }
                            break;
                        case "stop":
                            handleStopBackgroundLocationService(result);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Battery optimization channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_BATTERY)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "isBatteryOptimizationDisabled":
                            result.success(BackgroundLocationService.isBatteryOptimizationDisabled(this));
                            break;
                        case "requestDisableBatteryOptimization":
                            BackgroundLocationService.requestDisableBatteryOptimization(this);
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Android permissions channel for comprehensive permission handling
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_ANDROID_PERMISSIONS)
                .setMethodCallHandler((call, result) -> {
                    PermissionHelper.handleMethodCall(this, call, result);
                });

        // Native Driving Detection Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_DRIVING_DETECTION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initialize":
                            String userId = call.argument("userId");
                            if (userId != null) {
                                DrivingDetectionService.startService(this, userId);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "User ID is required", null);
                            }
                            break;
                        case "stop":
                            DrivingDetectionService.stopService(this);
                            result.success(true);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Native Emergency Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_EMERGENCY_SERVICE)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initialize":
                            // Emergency service doesn't need explicit initialization
                            result.success(true);
                            break;
                        case "startSos":
                            String userId = call.argument("userId");
                            if (userId != null) {
                                EmergencyService.startSos(this, userId);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "User ID is required", null);
                            }
                            break;
                        case "cancelSos":
                            EmergencyService.cancelSos(this);
                            result.success(true);
                            break;
                        case "triggerEmergency":
                            String emergencyUserId = call.argument("userId");
                            if (emergencyUserId != null) {
                                EmergencyService.triggerEmergency(this, emergencyUserId);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "User ID is required", null);
                            }
                            break;
                        case "cancelEmergency":
                            EmergencyService.cancelEmergency(this);
                            result.success(true);
                            break;
                        case "updateLocation":
                            Double latitude = call.argument("latitude");
                            Double longitude = call.argument("longitude");
                            Float accuracy = call.argument("accuracy");
                            if (latitude != null && longitude != null && accuracy != null) {
                                EmergencyService.updateLocation(this, latitude, longitude, accuracy);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "Location coordinates required", null);
                            }
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Native Geofence Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_GEOFENCE_SERVICE)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initialize":
                            String userId = call.argument("userId");
                            if (userId != null) {
                                GeofenceService.initialize(this, userId);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "User ID is required", null);
                            }
                            break;
                        case "addGeofence":
                            String geofenceUserId = call.argument("userId");
                            String geofenceId = call.argument("id");
                            Double lat = call.argument("latitude");
                            Double lng = call.argument("longitude");
                            Float radius = call.argument("radius");
                            String name = call.argument("name");
                            if (geofenceUserId != null && geofenceId != null && lat != null && lng != null && radius != null && name != null) {
                                GeofenceService.addGeofence(this, geofenceUserId, geofenceId, lat, lng, radius, name);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "Geofence parameters required", null);
                            }
                            break;
                        case "removeGeofence":
                            String removeId = call.argument("id");
                            if (removeId != null) {
                                GeofenceService.removeGeofence(this, removeId);
                                result.success(true);
                            } else {
                                result.error("INVALID_ARGUMENT", "Geofence ID required", null);
                            }
                            break;
                        case "clearAll":
                            GeofenceService.clearAllGeofences(this);
                            result.success(true);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }
    
    private void handleStartBackgroundLocationService(MethodCall call, MethodChannel.Result result) {
        try {
            String userId = call.argument("userId");
            if (userId == null || userId.isEmpty()) {
                result.error("INVALID_ARGUMENT", "User ID is required", null);
                return;
            }
            
            // Check if we have location permissions
            if (!hasLocationPermissions()) {
                result.error("PERMISSION_DENIED", "Location permissions not granted", null);
                return;
            }
            
            Intent serviceIntent = new Intent(this, BackgroundLocationService.class);
            serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start background location service: " + e.getMessage(), null);
        }
    }
    
    private void handleStartBackgroundLocationServiceLegacy(String userId, MethodChannel.Result result) {
        try {
            // Check if we have location permissions
            if (!hasLocationPermissions()) {
                result.error("PERMISSION_DENIED", "Location permissions not granted", null);
                return;
            }
            
            Intent serviceIntent = new Intent(this, BackgroundLocationService.class);
            serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            result.success(null);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start background location service: " + e.getMessage(), null);
        }
    }
    
    private void handleStopBackgroundLocationService(MethodChannel.Result result) {
        try {
            Intent serviceIntent = new Intent(this, BackgroundLocationService.class);
            stopService(serviceIntent);
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to stop background location service: " + e.getMessage(), null);
        }
    }
    
    private boolean isLocationServiceHealthy() {
        // Check if the background location service is running
        // This is a simplified check - in a real implementation, you might want to
        // check if the service is actually responding to health checks
        return true; // Placeholder implementation
    }
    
    private void requestBackgroundLocationPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
                != PackageManager.PERMISSION_GRANTED) {
                
                ActivityCompat.requestPermissions(this, 
                    new String[]{Manifest.permission.ACCESS_BACKGROUND_LOCATION}, 
                    BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE);
                
                // Note: The result will be handled in onRequestPermissionsResult
                // For now, we'll return false since permission is not yet granted
                result.success(false);
            } else {
                result.success(true);
            }
        } else {
            // Background location permission not needed for Android < Q
            result.success(true);
        }
    }
    
    private void registerBackgroundHandlers(MethodChannel.Result result) {
        // Register background task handlers
        // This would typically involve setting up WorkManager or JobScheduler
        // For now, we'll just return success
        result.success(true);
    }
    
    private boolean hasLocationPermissions() {
        boolean fineLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED;
        boolean coarseLocation = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED;
        
        return fineLocation && coarseLocation;
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE) {
            boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            // Handle the result - you might want to communicate this back to Flutter
            // through a method channel or event channel
        }
    }
}
