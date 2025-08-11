package com.sundeep.groupsharing

import android.content.Context
import android.location.Location
import android.util.Log
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Background Location Manager
 * 
 * This class handles smart location filtering and Firebase updates when the Flutter app
 * is killed or in background. It implements the same intelligent filtering logic
 * but runs entirely in native Android code.
 */
class BackgroundLocationManager private constructor() {
    
    companion object {
        private const val TAG = "BackgroundLocationMgr"
        
        @Volatile
        private var INSTANCE: BackgroundLocationManager? = null
        
        fun getInstance(): BackgroundLocationManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: BackgroundLocationManager().also { INSTANCE = it }
            }
        }
        
        // Distance thresholds for different modes (in meters)
        private const val SLEEP_MODE_THRESHOLD = 200.0
        private const val IDLE_MODE_THRESHOLD = 100.0
        private const val NORMAL_MODE_THRESHOLD = 50.0
        private const val ACTIVE_MODE_THRESHOLD = 25.0
        private const val DRIVING_MODE_THRESHOLD = 10.0
        
        // Time thresholds for forced updates (in milliseconds)
        private const val SLEEP_MODE_MAX_INTERVAL = 45 * 60 * 1000L // 45 minutes
        private const val IDLE_MODE_MAX_INTERVAL = 12 * 60 * 1000L // 12 minutes
        private const val NORMAL_MODE_MAX_INTERVAL = 3 * 60 * 1000L // 3 minutes
        private const val ACTIVE_MODE_MAX_INTERVAL = 1 * 60 * 1000L // 1 minute
        private const val DRIVING_MODE_MAX_INTERVAL = 20 * 1000L // 20 seconds
    }
    
    private var lastReportedLocation: Location? = null
    private var lastLocationUpdate: Long = 0
    private var currentTrackingMode: String = "NORMAL_MODE"
    private var currentUserId: String? = null
    
    private val firebaseDatabase = FirebaseDatabase.getInstance()
    
    /**
     * Initialize the background location manager
     */
    fun initialize(context: Context, userId: String) {
        this.currentUserId = userId
        loadLastKnownLocation(context)
        Log.d(TAG, "Background Location Manager initialized for user: ${userId.take(8)}")
    }
    
    /**
     * Process new location update with smart filtering
     */
    fun processLocationUpdate(context: Context, location: Location, trackingMode: String): Boolean {
        currentTrackingMode = trackingMode
        
        // Check if we should update location based on movement and time
        val shouldUpdate = shouldUpdateLocation(location)
        
        if (shouldUpdate) {
            updateLocationToFirebase(location)
            saveLastKnownLocation(context, location)
            lastReportedLocation = location
            lastLocationUpdate = System.currentTimeMillis()
            
            Log.d(TAG, "Location updated: ${location.latitude}, ${location.longitude} (Mode: $trackingMode)")
            return true
        } else {
            Log.d(TAG, "Location update skipped - no significant movement (Mode: $trackingMode)")
            return false
        }
    }
    
    /**
     * Send heartbeat to maintain online presence
     */
    fun sendHeartbeat() {
        currentUserId?.let { userId ->
            try {
                val heartbeatData = mapOf(
                    "lastHeartbeat" to ServerValue.TIMESTAMP,
                    "isOnline" to true,
                    "locationSharingEnabled" to true,
                    "trackingMode" to currentTrackingMode,
                    "appUninstalled" to false
                )
                
                firebaseDatabase.reference
                    .child("users")
                    .child(userId)
                    .updateChildren(heartbeatData)
                    .addOnSuccessListener {
                        Log.d(TAG, "Heartbeat sent successfully")
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to send heartbeat", e)
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending heartbeat", e)
            }
        }
    }
    
    /**
     * Check if location should be updated based on movement and time
     */
    private fun shouldUpdateLocation(newLocation: Location): Boolean {
        // Always update if no previous location
        if (lastReportedLocation == null) {
            Log.d(TAG, "First location update")
            return true
        }
        
        val lastLocation = lastReportedLocation!!
        
        // Calculate distance moved
        val distanceMoved = calculateDistance(lastLocation, newLocation)
        val threshold = getDistanceThreshold(currentTrackingMode)
        
        // Check if moved significantly
        val movedSignificantly = distanceMoved >= threshold
        
        // Check if max time interval reached
        val timeSinceLastUpdate = System.currentTimeMillis() - lastLocationUpdate
        val maxInterval = getMaxInterval(currentTrackingMode)
        val timeThresholdReached = timeSinceLastUpdate >= maxInterval
        
        Log.d(TAG, "Distance: ${distanceMoved.toInt()}m (threshold: ${threshold.toInt()}m), " +
                "Time: ${timeSinceLastUpdate/1000}s (max: ${maxInterval/1000}s)")
        
        return movedSignificantly || timeThresholdReached
    }
    
    /**
     * Update location to Firebase Realtime Database
     */
    private fun updateLocationToFirebase(location: Location) {
        currentUserId?.let { userId ->
            try {
                val locationData = mapOf(
                    "lat" to location.latitude,
                    "lng" to location.longitude,
                    "timestamp" to ServerValue.TIMESTAMP,
                    "isSharing" to true,
                    "accuracy" to location.accuracy.toDouble(),
                    "trackingMode" to currentTrackingMode,
                    "sleepState" to getSleepStateFromMode(currentTrackingMode)
                )
                
                firebaseDatabase.reference
                    .child("locations")
                    .child(userId)
                    .setValue(locationData)
                    .addOnSuccessListener {
                        Log.d(TAG, "Location synced to Firebase successfully")
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to sync location to Firebase", e)
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating location to Firebase", e)
            }
        }
    }
    
    /**
     * Get distance threshold for tracking mode
     */
    private fun getDistanceThreshold(mode: String): Double {
        return when (mode) {
            "SLEEP_MODE" -> SLEEP_MODE_THRESHOLD
            "IDLE_MODE" -> IDLE_MODE_THRESHOLD
            "ACTIVE_MODE" -> ACTIVE_MODE_THRESHOLD
            "DRIVING_MODE" -> DRIVING_MODE_THRESHOLD
            else -> NORMAL_MODE_THRESHOLD
        }
    }
    
    /**
     * Get max interval for tracking mode
     */
    private fun getMaxInterval(mode: String): Long {
        return when (mode) {
            "SLEEP_MODE" -> SLEEP_MODE_MAX_INTERVAL
            "IDLE_MODE" -> IDLE_MODE_MAX_INTERVAL
            "ACTIVE_MODE" -> ACTIVE_MODE_MAX_INTERVAL
            "DRIVING_MODE" -> DRIVING_MODE_MAX_INTERVAL
            else -> NORMAL_MODE_MAX_INTERVAL
        }
    }
    
    /**
     * Get sleep state from tracking mode
     */
    private fun getSleepStateFromMode(mode: String): String {
        return when (mode) {
            "SLEEP_MODE" -> "sleeping"
            "IDLE_MODE" -> "idle"
            "ACTIVE_MODE" -> "active"
            "DRIVING_MODE" -> "driving"
            else -> "awake"
        }
    }
    
    /**
     * Calculate distance between two locations using Haversine formula
     */
    private fun calculateDistance(loc1: Location, loc2: Location): Double {
        val earthRadius = 6371000.0 // Earth radius in meters
        
        val lat1Rad = Math.toRadians(loc1.latitude)
        val lat2Rad = Math.toRadians(loc2.latitude)
        val deltaLatRad = Math.toRadians(loc2.latitude - loc1.latitude)
        val deltaLngRad = Math.toRadians(loc2.longitude - loc1.longitude)
        
        val a = sin(deltaLatRad / 2).pow(2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLngRad / 2).pow(2)
        
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    /**
     * Save last known location to SharedPreferences
     */
    private fun saveLastKnownLocation(context: Context, location: Location) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putFloat("flutter.last_known_lat", location.latitude.toFloat())
                .putFloat("flutter.last_known_lng", location.longitude.toFloat())
                .putLong("flutter.last_location_time", System.currentTimeMillis())
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving last known location", e)
        }
    }
    
    /**
     * Load last known location from SharedPreferences
     */
    private fun loadLastKnownLocation(context: Context) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val lat = prefs.getFloat("flutter.last_known_lat", 0f)
            val lng = prefs.getFloat("flutter.last_known_lng", 0f)
            val time = prefs.getLong("flutter.last_location_time", 0)
            
            if (lat != 0f && lng != 0f) {
                lastReportedLocation = Location("saved").apply {
                    latitude = lat.toDouble()
                    longitude = lng.toDouble()
                }
                lastLocationUpdate = time
                Log.d(TAG, "Loaded last known location: $lat, $lng")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading last known location", e)
        }
    }
}