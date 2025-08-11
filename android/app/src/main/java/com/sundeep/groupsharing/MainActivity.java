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

// Kotlin classes will be accessed via reflection to avoid import issues

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_PERSISTENT_LOCATION = "persistent_location_service";
    private static final String CHANNEL_BACKGROUND_LOCATION = "background_location";
    private static final String CHANNEL_BATTERY = "com.sundeep.groupsharing/battery_optimization";
    private static final String CHANNEL_ANDROID_PERMISSIONS = "android_permissions";
    private static final String CHANNEL_DRIVING_DETECTION = "native_driving_detection";
    private static final String CHANNEL_EMERGENCY_SERVICE = "native_emergency_service";
    private static final String CHANNEL_GEOFENCE_SERVICE = "native_geofence_service";
    private static final String CHANNEL_BULLETPROOF_LOCATION = "bulletproof_location_service";
    private static final String CHANNEL_BULLETPROOF_PERMISSIONS = "bulletproof_permissions";
    private static final String CHANNEL_BULLETPROOF_BATTERY = "bulletproof_battery";
    private static final String CHANNEL_PERSISTENT_NOTIFICATION = "persistent_foreground_notification";
    private static final String CHANNEL_PERSISTENT_FOREGROUND_SERVICE = "persistent_foreground_service";
    private static final String CHANNEL_ACTIVITY_RECOGNITION = "activity_recognition_service";
    private static final String CHANNEL_SLEEP_DETECTION = "sleep_detection_service";
    private static final String CHANNEL_NETWORK_MOVEMENT = "network_movement_detector";
    private static final String CHANNEL_SENSOR_FUSION = "sensor_fusion_detector";
    private static final int LOCATION_PERMISSION_REQUEST_CODE = 1001;
    private static final int BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE = 1002;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Activity Recognition Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_ACTIVITY_RECOGNITION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startActivityRecognition":
                            handleStartActivityRecognition(result);
                            break;
                        case "stopActivityRecognition":
                            handleStopActivityRecognition(result);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });
        
        // Sleep Detection Service Channel - Temporarily disabled for build fix
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_SLEEP_DETECTION)
                .setMethodCallHandler((call, result) -> {
                    // TODO: Implement sleep detection handlers
                    result.success(true);
                });
        
        // Network Movement Detection Channel - Temporarily disabled for build fix
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NETWORK_MOVEMENT)
                .setMethodCallHandler((call, result) -> {
                    // TODO: Implement network movement handlers
                    result.success(true);
                });
        
        // Sensor Fusion Detection Channel - Temporarily disabled for build fix
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_SENSOR_FUSION)
                .setMethodCallHandler((call, result) -> {
                    // TODO: Implement sensor fusion handlers
                    result.success(true);
                });
        
        // Persistent Location Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_PERSISTENT_LOCATION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initialize":
                            result.success(true);
                            break;
                        case "startPersistentService":
                            handleStartPersistentLocationService(call, result);
                            break;
                        case "stopPersistentService":
                            handleStopPersistentLocationService(result);
                            break;
                        case "startBackgroundLocationService":
                            handleStartBackgroundLocationService(call, result);
                            break;
                        case "stopBackgroundLocationService":
                            handleStopBackgroundLocationService(result);
                            break;
                        case "isServiceHealthy":
                            result.success(isPersistentLocationServiceHealthy());
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
                        case "startLocationService":
                            handleStartLocationService(call, result);
                            break;
                        case "stop":
                            handleStopBackgroundLocationService(result);
                            break;
                        case "updateNow":
                            handleUpdateNowAction(result);
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
                            result.success(BatteryOptimizationHelper.INSTANCE.isBatteryOptimizationDisabled(this));
                            break;
                        case "requestDisableBatteryOptimization":
                            BatteryOptimizationHelper.INSTANCE.requestBatteryOptimizationExemption(this);
                            result.success(null);
                            break;
                        case "checkDeviceSpecificOptimizations":
                            // Device-specific optimizations are handled automatically
                            result.success(true);
                            break;
                        case "requestAutoStartPermission":
                            BatteryOptimizationHelper.INSTANCE.requestAutoStartPermission(this);
                            result.success(null);
                            break;
                        case "requestBackgroundAppPermission":
                            BatteryOptimizationHelper.INSTANCE.requestBackgroundAppPermission(this);
                            result.success(null);
                            break;
                        case "openBackgroundActivitySettings":
                            BatteryOptimizationHelper.INSTANCE.openBackgroundActivitySettings(this);
                            result.success(null);
                            break;
                        case "getComprehensiveOptimizationStatus":
                            // Return comprehensive status
                            java.util.Map<String, Object> status = new java.util.HashMap<>();
                            status.put("batteryOptimizationDisabled", BatteryOptimizationHelper.INSTANCE.isBatteryOptimizationDisabled(this));
                            status.put("autoStartEnabled", true); // Simplified check
                            status.put("backgroundAppEnabled", true); // Simplified check
                            status.put("deviceManufacturer", android.os.Build.MANUFACTURER);
                            result.success(status);
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

        // Bulletproof Location Service Channel
        MethodChannel bulletproofChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_BULLETPROOF_LOCATION);
        BulletproofLocationService.setMethodChannel(bulletproofChannel);
        bulletproofChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "initialize":
                    result.success(true);
                    break;
                case "initializeIOS":
                    result.success(true);
                    break;
                case "startBulletproofService":
                    handleStartBulletproofService(call, result);
                    break;
                case "stopBulletproofService":
                    handleStopBulletproofService(result);
                    break;
                case "checkServiceHealth":
                    result.success(BulletproofLocationService.isRunning());
                    break;
                case "setupDeviceOptimizations":
                    // Device optimizations are handled in the service
                    result.success(true);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });

        // Bulletproof Permissions Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_BULLETPROOF_PERMISSIONS)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initializePermissionMonitoring":
                            result.success(true);
                            break;
                        case "checkBackgroundLocationPermission":
                            result.success(BulletproofPermissionHelper.INSTANCE.hasBackgroundLocationPermission(this));
                            break;
                        case "requestBackgroundLocationPermission":
                            BulletproofPermissionHelper.INSTANCE.requestBackgroundLocationPermission(this);
                            result.success(true);
                            break;
                        case "checkExactAlarmPermission":
                            result.success(BulletproofPermissionHelper.INSTANCE.hasExactAlarmPermission(this));
                            break;
                        case "requestExactAlarmPermission":
                            BulletproofPermissionHelper.INSTANCE.requestExactAlarmPermission(this);
                            result.success(true);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Bulletproof Battery Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_BULLETPROOF_BATTERY)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initializeBatteryOptimizations":
                            result.success(true);
                            break;
                        case "requestBatteryOptimizationExemption":
                            BatteryOptimizationHelper.INSTANCE.requestBatteryOptimizationExemption(this);
                            result.success(true);
                            break;
                        case "requestAutoStartPermission":
                            BatteryOptimizationHelper.INSTANCE.requestAutoStartPermission(this);
                            result.success(true);
                            break;
                        case "requestBackgroundAppPermission":
                            BatteryOptimizationHelper.INSTANCE.requestBackgroundAppPermission(this);
                            result.success(true);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Persistent Foreground Notification Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_PERSISTENT_NOTIFICATION)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "initializeNotification":
                            result.success(true);
                            break;
                        case "createPersistentNotification":
                            handleCreatePersistentNotification(call, result);
                            break;
                        case "updateNotification":
                            handleUpdateNotification(call, result);
                            break;
                        case "removeNotification":
                            handleRemoveNotification(call, result);
                            break;
                        case "makeNotificationPersistent":
                            handleMakeNotificationPersistent(call, result);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                });

        // Persistent Foreground Service Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_PERSISTENT_FOREGROUND_SERVICE)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startForegroundService":
                            handleStartPersistentForegroundService(call, result);
                            break;
                        case "stopForegroundService":
                            handleStopPersistentForegroundService(result);
                            break;
                        case "sendHeartbeat":
                            handleSendHeartbeat(call, result);
                            break;
                        case "openApp":
                            handleOpenApp(call, result);
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
    
    private void handleStartLocationService(MethodCall call, MethodChannel.Result result) {
        try {
            String userId = call.argument("userId");
            if (userId == null || userId.isEmpty()) {
                result.error("INVALID_ARGUMENT", "User ID is required", null);
                return;
            }
            
            // Check battery optimization first
            if (!BackgroundLocationService.isBatteryOptimizationDisabled(this)) {
                BackgroundLocationService.requestDisableBatteryOptimization(this);
            }
            
            // Check if we have location permissions
            if (!hasLocationPermissions()) {
                result.error("PERMISSION_DENIED", "Location permissions not granted", null);
                return;
            }
            
            // Save location sharing state to SharedPreferences
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .edit()
                .putBoolean("flutter.location_sharing_enabled", true)
                .apply();
            
            Intent serviceIntent = new Intent(this, BackgroundLocationService.class);
            serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start location service: " + e.getMessage(), null);
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
    
    private void handleUpdateNowAction(MethodChannel.Result result) {
        try {
            // Send the UPDATE_NOW action to the background location service
            Intent updateIntent = new Intent(this, BackgroundLocationService.class);
            updateIntent.setAction("com.sundeep.groupsharing.UPDATE_NOW");
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(updateIntent);
            } else {
                startService(updateIntent);
            }
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to trigger update now: " + e.getMessage(), null);
        }
    }
    
    private void handleStartPersistentLocationService(MethodCall call, MethodChannel.Result result) {
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
            
            // Start persistent location service
            PersistentLocationService.startPersistentService(this, userId);
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start persistent location service: " + e.getMessage(), null);
        }
    }
    
    private void handleStopPersistentLocationService(MethodChannel.Result result) {
        try {
            PersistentLocationService.stopPersistentService(this);
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to stop persistent location service: " + e.getMessage(), null);
        }
    }
    
    private boolean isPersistentLocationServiceHealthy() {
        try {
            return PersistentLocationService.isServiceRunning(this);
        } catch (Exception e) {
            return false;
        }
    }
    
    private void handleStartActivityRecognition(MethodChannel.Result result) {
        try {
            // Check for activity recognition permission on Android 10+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) 
                        != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(this, 
                            new String[]{Manifest.permission.ACTIVITY_RECOGNITION}, 
                            1003);
                    result.error("PERMISSION_DENIED", "Activity recognition permission not granted", null);
                    return;
                }
            }
            
            // Start the Activity Detection Service
            Intent serviceIntent = new Intent(this, ActivityDetectionService.class);
            startService(serviceIntent);
            
            // Set the method channel in the receiver for callbacks
            ActivityRecognitionReceiver.methodChannel = 
                    new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL_ACTIVITY_RECOGNITION);
            
            result.success(true);
        } catch (Exception e) {
            result.error("START_FAILED", "Failed to start activity recognition: " + e.getMessage(), null);
        }
    }
    
    private void handleStopActivityRecognition(MethodChannel.Result result) {
        try {
            // Stop the Activity Detection Service
            Intent serviceIntent = new Intent(this, ActivityDetectionService.class);
            stopService(serviceIntent);
            
            // Clear the method channel reference
            ActivityRecognitionReceiver.methodChannel = null;
            
            result.success(true);
        } catch (Exception e) {
            result.error("STOP_FAILED", "Failed to stop activity recognition: " + e.getMessage(), null);
        }
    }
    
    // Handler methods temporarily removed for build fix
    // TODO: Re-implement these methods with proper Kotlin interop

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
    
    private void handleStartBulletproofService(MethodCall call, MethodChannel.Result result) {
        try {
            String userId = call.argument("userId");
            if (userId == null || userId.isEmpty()) {
                result.error("INVALID_ARGUMENT", "User ID is required", null);
                return;
            }
            
            // Check if we have location permissions
            if (!BulletproofPermissionHelper.INSTANCE.hasLocationPermissions(this)) {
                result.error("PERMISSION_DENIED", "Location permissions not granted", null);
                return;
            }
            
            Intent serviceIntent = new Intent(this, BulletproofLocationService.class);
            serviceIntent.putExtra("userId", userId);
            serviceIntent.putExtra("updateInterval", (Long) call.argument("updateInterval"));
            serviceIntent.putExtra("distanceFilter", (Float) call.argument("distanceFilter"));
            serviceIntent.putExtra("enableHighAccuracy", (Boolean) call.argument("enableHighAccuracy"));
            serviceIntent.putExtra("enablePersistentMode", (Boolean) call.argument("enablePersistentMode"));
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start bulletproof location service: " + e.getMessage(), null);
        }
    }
    
    private void handleStopBulletproofService(MethodChannel.Result result) {
        try {
            Intent serviceIntent = new Intent(this, BulletproofLocationService.class);
            stopService(serviceIntent);
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to stop bulletproof location service: " + e.getMessage(), null);
        }
    }
    
    private boolean hasBackgroundLocationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
                == PackageManager.PERMISSION_GRANTED;
        }
        return true; // Not required for Android < Q
    }
    
    private boolean hasExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Check if exact alarm permission is granted
            // This is a simplified check - you might want to use AlarmManager.canScheduleExactAlarms()
            return true; // Placeholder implementation
        }
        return true; // Not required for Android < S
    }
    
    private void requestExactAlarmPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Request exact alarm permission
            // This typically involves directing user to settings
            result.success(true);
        } else {
            result.success(true);
        }
    }

    // Persistent Notification Service Handlers
    
    private void handleCreatePersistentNotification(MethodCall call, MethodChannel.Result result) {
        try {
            // The notification creation is handled by the service itself
            result.success(true);
        } catch (Exception e) {
            result.error("NOTIFICATION_ERROR", "Failed to create persistent notification: " + e.getMessage(), null);
        }
    }
    
    private void handleUpdateNotification(MethodCall call, MethodChannel.Result result) {
        try {
            String title = call.argument("title");
            String content = call.argument("content");
            String status = call.argument("status");
            Integer friendsCount = call.argument("friendsCount");
            Boolean isSharing = call.argument("isSharing");
            Double latitude = call.argument("latitude");
            Double longitude = call.argument("longitude");
            
            // Update notification through the service
            // This would require a static method or service reference
            result.success(true);
        } catch (Exception e) {
            result.error("NOTIFICATION_ERROR", "Failed to update notification: " + e.getMessage(), null);
        }
    }
    
    private void handleRemoveNotification(MethodCall call, MethodChannel.Result result) {
        try {
            // Stop the foreground service which will remove the notification
            Intent serviceIntent = new Intent(this, PersistentForegroundNotificationService.class);
            stopService(serviceIntent);
            result.success(true);
        } catch (Exception e) {
            result.error("NOTIFICATION_ERROR", "Failed to remove notification: " + e.getMessage(), null);
        }
    }
    
    private void handleMakeNotificationPersistent(MethodCall call, MethodChannel.Result result) {
        try {
            // This is handled by the service itself
            result.success(true);
        } catch (Exception e) {
            result.error("NOTIFICATION_ERROR", "Failed to make notification persistent: " + e.getMessage(), null);
        }
    }
    
    private void handleStartPersistentForegroundService(MethodCall call, MethodChannel.Result result) {
        try {
            String userId = call.argument("userId");
            if (userId == null || userId.isEmpty()) {
                result.error("INVALID_ARGUMENT", "User ID is required", null);
                return;
            }
            
            Intent serviceIntent = new Intent(this, PersistentForegroundNotificationService.class);
            serviceIntent.putExtra("userId", userId);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent);
            } else {
                startService(serviceIntent);
            }
            
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to start persistent foreground service: " + e.getMessage(), null);
        }
    }
    
    private void handleStopPersistentForegroundService(MethodChannel.Result result) {
        try {
            Intent serviceIntent = new Intent(this, PersistentForegroundNotificationService.class);
            stopService(serviceIntent);
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to stop persistent foreground service: " + e.getMessage(), null);
        }
    }
    
    private void handleSendHeartbeat(MethodCall call, MethodChannel.Result result) {
        try {
            Long timestamp = call.argument("timestamp");
            Boolean isLocationSharing = call.argument("isLocationSharing");
            Integer friendsCount = call.argument("friendsCount");
            
            // Send heartbeat to service
            // This would require a static method or service reference
            result.success(true);
        } catch (Exception e) {
            result.error("SERVICE_ERROR", "Failed to send heartbeat: " + e.getMessage(), null);
        }
    }
    
    private void handleOpenApp(MethodCall call, MethodChannel.Result result) {
        try {
            String screen = call.argument("screen");
            
            Intent intent = new Intent(this, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            if (screen != null) {
                intent.putExtra("screen", screen);
            }
            startActivity(intent);
            
            result.success(true);
        } catch (Exception e) {
            result.error("APP_ERROR", "Failed to open app: " + e.getMessage(), null);
        }
    }
}
