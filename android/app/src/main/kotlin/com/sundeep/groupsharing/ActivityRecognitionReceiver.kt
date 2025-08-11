package com.sundeep.groupsharing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.Calendar
import android.location.Location
import android.location.LocationManager

/**
 * Activity Recognition Receiver
 * 
 * This BroadcastReceiver handles activity recognition updates from Google Play Services.
 * It analyzes the detected activities and triggers location sharing when significant
 * movement is detected, even when the app has been killed by OEMs.
 */
class ActivityRecognitionReceiver : BroadcastReceiver() {
    
    companion object {
        // Static method channel for communication with Flutter
        @JvmField
        var methodChannel: MethodChannel? = null
        
        private const val TAG = "ActivityRecognition"
        
        // Constants for activity types
        private val TRIGGER_ACTIVITIES = setOf(
            DetectedActivity.WALKING,
            DetectedActivity.RUNNING,
            DetectedActivity.ON_BICYCLE,
            DetectedActivity.IN_VEHICLE
        )
        private const val CONFIDENCE_THRESHOLD = 70
        
        // Smart location update cooldowns based on activity
        private const val SLEEP_MODE_COOLDOWN_MS = 45 * 60 * 1000L // 45 minutes
        private const val IDLE_MODE_COOLDOWN_MS = 12 * 60 * 1000L // 12 minutes
        private const val NORMAL_MODE_COOLDOWN_MS = 3 * 60 * 1000L // 3 minutes
        private const val ACTIVE_MODE_COOLDOWN_MS = 1 * 60 * 1000L // 1 minute
        private const val DRIVING_MODE_COOLDOWN_MS = 20 * 1000L // 20 seconds
        
        private var lastLocationTriggerTime = 0L
        private var currentTrackingMode = "NORMAL_MODE"
        
        // Executor for background tasks
        private val executor = Executors.newSingleThreadScheduledExecutor()
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent)
            result?.let { handleActivityUpdate(context, it) }
        }
    }
    
    private fun handleActivityUpdate(context: Context, result: ActivityRecognitionResult) {
        val mostProbableActivity = result.mostProbableActivity
        val activities = result.probableActivities
        
        // Log all detected activities
        for (activity in activities) {
            Log.d(TAG, "Activity: ${getActivityString(activity.type)}, " +
                "Confidence: ${activity.confidence}%")
        }
        
        // Check if any trigger activity has high confidence
        for (activity in activities) {
            if (activity.confidence > CONFIDENCE_THRESHOLD && isTriggerActivity(activity.type)) {
                triggerLocationSharing(context, activity)
                break
            }
        }
        
        // Also check if most probable activity is a trigger activity
        if (mostProbableActivity.confidence > CONFIDENCE_THRESHOLD && 
            isTriggerActivity(mostProbableActivity.type)) {
            triggerLocationSharing(context, mostProbableActivity)
        }
        
        // Handle stationary state to potentially reduce location updates
        if (mostProbableActivity.type == DetectedActivity.STILL && 
            mostProbableActivity.confidence > CONFIDENCE_THRESHOLD) {
            handleStationaryState(context)
        }
    }
    
    private fun triggerLocationSharing(context: Context, activity: DetectedActivity) {
        val currentTime = System.currentTimeMillis()
        
        // Determine tracking mode and cooldown based on activity and time
        val trackingMode = determineTrackingMode(activity, context)
        val cooldownMs = getCooldownForMode(trackingMode)
        
        // Check smart cooldown based on current mode
        if (currentTime - lastLocationTriggerTime < cooldownMs) {
            Log.d(TAG, "Location trigger on cooldown for $trackingMode (${cooldownMs/1000}s), skipping")
            return
        }
        
        lastLocationTriggerTime = currentTime
        currentTrackingMode = trackingMode
        
        Log.d(TAG, "Triggering location sharing for activity: ${getActivityString(activity.type)} (Mode: $trackingMode)")
        
        // Send event to Flutter with tracking mode
        sendActivityEvent(activity, trackingMode)
        // Also send detailed activity update to Flutter
        sendActivityUpdateToFlutter(activity.type, activity.confidence)
        
        // Start location services based on tracking mode
        when (trackingMode) {
            "DRIVING_MODE" -> startLocationService(context, true)
            "ACTIVE_MODE" -> startLocationService(context, true)
            "SLEEP_MODE" -> startLocationService(context, false, true) // Sleep mode
            "IDLE_MODE" -> startLocationService(context, false, false) // Idle mode
            else -> startLocationService(context, false) // Normal mode
        }
    }
    
    private fun determineTrackingMode(activity: DetectedActivity, context: Context): String {
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val isNightTime = currentHour >= 22 || currentHour <= 6
        
        return when {
            // Sleep mode: Still + Night time + Phone idle
            activity.type == DetectedActivity.STILL && isNightTime && isPhoneIdle(context) -> "SLEEP_MODE"
            
            // Driving mode: In vehicle with high confidence
            activity.type == DetectedActivity.IN_VEHICLE && activity.confidence > 80 -> "DRIVING_MODE"
            
            // Active mode: Walking, running, cycling
            activity.type in setOf(DetectedActivity.WALKING, DetectedActivity.RUNNING, DetectedActivity.ON_BICYCLE) -> "ACTIVE_MODE"
            
            // Idle mode: Still during day or low confidence movement
            activity.type == DetectedActivity.STILL && !isNightTime -> "IDLE_MODE"
            
            // Normal mode: Everything else
            else -> "NORMAL_MODE"
        }
    }
    
    private fun getCooldownForMode(mode: String): Long {
        return when (mode) {
            "SLEEP_MODE" -> SLEEP_MODE_COOLDOWN_MS
            "IDLE_MODE" -> IDLE_MODE_COOLDOWN_MS
            "ACTIVE_MODE" -> ACTIVE_MODE_COOLDOWN_MS
            "DRIVING_MODE" -> DRIVING_MODE_COOLDOWN_MS
            else -> NORMAL_MODE_COOLDOWN_MS
        }
    }
    
    private fun sendActivityUpdateToFlutter(activityType: Int, confidence: Int) {
        try {
            // Only send if method channel is available
            methodChannel?.let { channel ->
                val activityData = HashMap<String, Any>()
                activityData["type"] = activityType
                activityData["typeString"] = getActivityString(activityType)
                activityData["confidence"] = confidence
                
                // Send activity update to Flutter on the main thread
                Handler(Looper.getMainLooper()).post {
                    channel.invokeMethod("onActivityUpdate", activityData)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send activity update to Flutter", e)
        }
    }
    
    private fun handleStationaryState(context: Context) {
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val isNightTime = currentHour >= 22 || currentHour <= 6
        
        Log.d(TAG, "Device is stationary, checking for sleep mode (night time: $isNightTime)")
        
        // Send stationary event to Flutter
        val stationaryActivity = DetectedActivity(DetectedActivity.STILL, 100)
        sendActivityEvent(stationaryActivity)
        
        // Check if we should enter sleep mode
        if (isNightTime && isPhoneIdle(context)) {
            Log.d(TAG, "Entering sleep mode - very low frequency updates")
            setSleepMode(context, true)
        } else {
            Log.d(TAG, "Regular stationary state - reducing frequency")
        }
        
        // Schedule reduced location updates after delay
        executor.schedule({
            // Check if services are running before modifying
            if (UltraGeofencingService.isRunning) {
                // Reduce location update frequency
                // This is handled by the service itself based on the activity type
            }
        }, 2, TimeUnit.MINUTES)
    }
    
    private fun isPhoneIdle(context: Context): Boolean {
        // Simple check - can be enhanced with more sophisticated detection
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastInteraction = prefs.getLong("flutter.last_screen_interaction", 0)
        val currentTime = System.currentTimeMillis()
        
        // Consider phone idle if no interaction for 30 minutes
        return (currentTime - lastInteraction) > (30 * 60 * 1000)
    }
    
    private fun setSleepMode(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.sleep_mode_enabled", enabled).apply()
        
        // Notify Flutter about sleep mode change
        sendSleepModeUpdate(enabled)
    }
    
    private fun sendSleepModeUpdate(sleepMode: Boolean) {
        try {
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onSleepModeChanged", mapOf(
                    "sleepMode" to sleepMode,
                    "timestamp" to System.currentTimeMillis()
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending sleep mode update to Flutter", e)
        }
    }
    
    private fun startLocationService(context: Context, highFrequency: Boolean, sleepMode: Boolean = false) {
        try {
            // Get stored user ID from shared preferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val userId = prefs.getString("flutter.current_user_id", null)
            
            if (userId != null) {
                // Initialize background location manager for native filtering
                BackgroundLocationManager.getInstance().initialize(context, userId)
                
                // Start UltraGeofencingService if not already running
                val serviceIntent = Intent(context, UltraGeofencingService::class.java).apply {
                    putExtra("userId", userId)
                    putExtra("ultraActive", highFrequency)
                    putExtra("sleepMode", sleepMode)
                    putExtra("trackingMode", currentTrackingMode)
                }
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                // Send heartbeat to maintain online presence
                BackgroundLocationManager.getInstance().sendHeartbeat()
                
                Log.d(TAG, "Started location service - Mode: $currentTrackingMode, High freq: $highFrequency, Sleep: $sleepMode")
            } else {
                Log.d(TAG, "No user ID found, cannot start location service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting location service", e)
        }
    }
    
    /**
     * Process location update with smart filtering (called from native location services)
     */
    fun processLocationUpdate(context: Context, latitude: Double, longitude: Double, accuracy: Float) {
        try {
            val location = Location("gps").apply {
                this.latitude = latitude
                this.longitude = longitude
                this.accuracy = accuracy
                time = System.currentTimeMillis()
            }
            
            // Use BackgroundLocationManager for smart filtering
            val updated = BackgroundLocationManager.getInstance()
                .processLocationUpdate(context, location, currentTrackingMode)
            
            if (updated) {
                Log.d(TAG, "Location updated via background manager")
                
                // Send to Flutter if app is running
                sendLocationUpdateToFlutter(latitude, longitude, accuracy)
            } else {
                Log.d(TAG, "Location update filtered out by background manager")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing location update", e)
        }
    }
    
    private fun sendLocationUpdateToFlutter(latitude: Double, longitude: Double, accuracy: Float) {
        try {
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onLocationUpdate", mapOf(
                    "latitude" to latitude,
                    "longitude" to longitude,
                    "accuracy" to accuracy,
                    "timestamp" to System.currentTimeMillis(),
                    "trackingMode" to currentTrackingMode
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending location update to Flutter", e)
        }
    }
    
    private fun sendActivityEvent(activity: DetectedActivity, trackingMode: String = "NORMAL_MODE") {
        try {
            // Send to Flutter on main thread
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onActivityDetected", mapOf(
                    "activityType" to activity.type,
                    "activityName" to getActivityString(activity.type),
                    "confidence" to activity.confidence,
                    "timestamp" to System.currentTimeMillis(),
                    "trackingMode" to trackingMode,
                    "sleepState" to getSleepStateFromMode(trackingMode)
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending activity event to Flutter", e)
        }
    }
    
    private fun getSleepStateFromMode(mode: String): String {
        return when (mode) {
            "SLEEP_MODE" -> "sleeping"
            "IDLE_MODE" -> "idle"
            "ACTIVE_MODE" -> "active"
            "DRIVING_MODE" -> "driving"
            else -> "awake"
        }
    }
    
    private fun isTriggerActivity(activityType: Int): Boolean {
        return TRIGGER_ACTIVITIES.contains(activityType)
    }
    
    private fun getActivityString(activityType: Int): String {
        return when (activityType) {
            DetectedActivity.IN_VEHICLE -> "In Vehicle"
            DetectedActivity.ON_BICYCLE -> "On Bicycle"
            DetectedActivity.ON_FOOT -> "On Foot"
            DetectedActivity.RUNNING -> "Running"
            DetectedActivity.STILL -> "Still"
            DetectedActivity.TILTING -> "Tilting"
            DetectedActivity.WALKING -> "Walking"
            else -> "Unknown"
        }
    }
}