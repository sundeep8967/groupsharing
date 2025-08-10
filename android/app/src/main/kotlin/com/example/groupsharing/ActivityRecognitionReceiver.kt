package com.example.groupsharing

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
        @JvmStatic
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
        
        // Cooldown period to prevent excessive location updates
        private const val LOCATION_TRIGGER_COOLDOWN_MS = 5 * 60 * 1000L // 5 minutes
        private var lastLocationTriggerTime = 0L
        
        // Executor for background tasks
        private val executor = Executors.newSingleThreadScheduledExecutor()
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent)
            handleActivityUpdate(context, result)
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
        
        // Check cooldown to prevent excessive updates
        if (currentTime - lastLocationTriggerTime < LOCATION_TRIGGER_COOLDOWN_MS) {
            Log.d(TAG, "Location trigger on cooldown, skipping")
            return
        }
        
        lastLocationTriggerTime = currentTime
        
        Log.d(TAG, "Triggering location sharing for activity: ${getActivityString(activity.type)}")
        
        // Send event to Flutter
        sendActivityEvent(activity)
        // Also send detailed activity update to Flutter
        sendActivityUpdateToFlutter(activity.type, activity.confidence)
        
        // Start location services based on activity type
        when (activity.type) {
            DetectedActivity.IN_VEHICLE -> {
                // Higher frequency updates for driving
                startLocationService(context, true)
            }
            else -> {
                // Normal updates for other activities
                startLocationService(context, false)
            }
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
        Log.d(TAG, "Device is stationary, reducing location update frequency")
        
        // Send stationary event to Flutter
        val stationaryActivity = DetectedActivity(DetectedActivity.STILL, 100)
        sendActivityEvent(stationaryActivity)
        
        // Schedule reduced location updates after delay
        executor.schedule({
            // Check if services are running before modifying
            if (UltraGeofencingService.isRunning) {
                // Reduce location update frequency
                // This is handled by the service itself based on the activity type
            }
        }, 2, TimeUnit.MINUTES)
    }
    
    private fun startLocationService(context: Context, highFrequency: Boolean) {
        try {
            // Get stored user ID from shared preferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val userId = prefs.getString("flutter.current_user_id", null)
            
            if (userId != null) {
                // Start UltraGeofencingService if not already running
                val serviceIntent = Intent(context, UltraGeofencingService::class.java).apply {
                    putExtra("userId", userId)
                    putExtra("ultraActive", highFrequency)
                }
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                Log.d(TAG, "Started location service with high frequency: $highFrequency")
            } else {
                Log.d(TAG, "No user ID found, cannot start location service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting location service", e)
        }
    }
    
    private fun sendActivityEvent(activity: DetectedActivity) {
        try {
            // Send to Flutter on main thread
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onActivityDetected", mapOf(
                    "activityType" to activity.type,
                    "activityName" to getActivityString(activity.type),
                    "confidence" to activity.confidence,
                    "timestamp" to System.currentTimeMillis()
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending activity event to Flutter", e)
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