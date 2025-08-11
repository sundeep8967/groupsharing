package com.sundeep.groupsharing

import android.app.IntentService
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import android.app.PendingIntent
import android.content.Context
import android.os.Build

/**
 * Activity Detection Service for Android
 * 
 * This service uses Google Play Services Activity Recognition API to detect user activities
 * and trigger location updates based on movement. This approach is more reliable for background
 * operation because:
 * 
 * 1. Google Play Services Integration: Activity Recognition uses Google Play Services, which has
 *    system-level privileges that regular apps don't have
 * 2. Hardware-Level Detection: Uses accelerometer/gyroscope which work even in Doze mode
 * 3. Lower Power Consumption: More battery-efficient than continuous GPS
 * 4. OEM Tolerance: Most OEMs don't aggressively kill activity recognition services
 */
class ActivityDetectionService : IntentService("ActivityDetectionService") {
    
    companion object {
        private const val TAG = "ActivityDetection"
        private const val ACTIVITY_REQUEST_CODE = 1001
        private val TRIGGER_ACTIVITIES = setOf(
            DetectedActivity.WALKING,
            DetectedActivity.RUNNING,
            DetectedActivity.ON_BICYCLE,
            DetectedActivity.IN_VEHICLE
        )
        
        // Static methods for starting/stopping from Flutter
        fun startActivityRecognition(context: Context) {
            val intent = Intent(context, ActivityDetectionService::class.java)
            context.startService(intent)
        }
        
        fun stopActivityRecognition(context: Context) {
            val intent = Intent(context, ActivityDetectionService::class.java)
            context.stopService(intent)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        startActivityRecognition()
    }
    
    private fun startActivityRecognition() {
        val activityRecognitionClient = ActivityRecognition.getClient(this)
        
        val intent = Intent(this, ActivityRecognitionReceiver::class.java)
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getBroadcast(
                this,
                ACTIVITY_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getBroadcast(
                this,
                ACTIVITY_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        // Request activity updates every 30 seconds
        activityRecognitionClient.requestActivityUpdates(30000, pendingIntent)
            .addOnSuccessListener {
                Log.d(TAG, "Activity recognition started")
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Failed to start activity recognition", exception)
            }
    }
    
    override fun onHandleIntent(intent: Intent?) {
        // This method is called when the service is started
        // The actual activity updates are handled by the BroadcastReceiver
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Remove activity recognition updates
        val activityRecognitionClient = ActivityRecognition.getClient(this)
        
        val intent = Intent(this, ActivityRecognitionReceiver::class.java)
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.getBroadcast(
                this,
                ACTIVITY_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        } else {
            PendingIntent.getBroadcast(
                this,
                ACTIVITY_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        
        activityRecognitionClient.removeActivityUpdates(pendingIntent)
            .addOnSuccessListener {
                Log.d(TAG, "Activity recognition stopped")
            }
            .addOnFailureListener { exception ->
                Log.e(TAG, "Failed to stop activity recognition", exception)
            }
    }
}