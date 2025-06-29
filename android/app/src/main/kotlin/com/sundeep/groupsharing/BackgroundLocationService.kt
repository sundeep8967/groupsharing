package com.sundeep.groupsharing

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.auth.FirebaseAuth
import android.util.Log
import java.util.*

class BackgroundLocationService : Service() {
    
    companion object {
        private const val TAG = "BackgroundLocationService"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "background_location_channel"
        private const val LOCATION_UPDATE_INTERVAL = 15000L // 15 seconds
        private const val FASTEST_LOCATION_INTERVAL = 5000L // 5 seconds
        private const val LOCATION_DISTANCE_THRESHOLD = 10f // 10 meters
        const val EXTRA_USER_ID = "userId"
        
        fun startService(context: Context, userId: String) {
            val intent = Intent(context, BackgroundLocationService::class.java)
            intent.putExtra("userId", userId)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, BackgroundLocationService::class.java)
            context.stopService(intent)
        }
        
        @JvmStatic
        fun isBatteryOptimizationDisabled(context: Context): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true // Battery optimization doesn't exist on older versions
            }
        }
        
        @JvmStatic
        fun requestDisableBatteryOptimization(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = android.net.Uri.parse("package:${context.packageName}")
                    if (context is Activity) {
                        context.startActivity(intent)
                    } else {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                    }
                }
            }
        }
    }
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    private var userId: String? = null
    private var isLocationUpdatesActive = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var heartbeatTimer: Timer? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Background location service created")
        
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createLocationRequest()
        createLocationCallback()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Background location service started")
        
        userId = intent?.getStringExtra("userId")
        
        if (userId.isNullOrEmpty()) {
            Log.e(TAG, "No user ID provided, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }
        
        // Save state for persistence
        saveServiceState(true, userId!!)
        
        // Start foreground service immediately - critical for Android 8+
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Acquire wake lock to prevent doze mode from killing service
        acquireWakeLock()
        
        startLocationUpdates()
        
        // Send heartbeat every 30 seconds
        startHeartbeat()
        
        // Schedule work manager for additional reliability
        scheduleLocationWork()
        
        Log.d(TAG, "Background location service fully initialized for user: ${userId!!.substring(0, 8)}")
        
        // Return START_STICKY to restart service if killed - like Life360
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Background location service destroyed")
        
        // Clean up resources
        stopLocationUpdates()
        releaseWakeLock()
        stopHeartbeat()
        
        // Save state
        saveServiceState(false, null)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Location",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Tracks your location in the background to share with family"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Sharing your location with family members")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun createLocationRequest() {
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, LOCATION_UPDATE_INTERVAL)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(FASTEST_LOCATION_INTERVAL)
            .setMinUpdateDistanceMeters(LOCATION_DISTANCE_THRESHOLD)
            .build()
    }
    
    private fun createLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "New location: ${location.latitude}, ${location.longitude}")
                    updateLocationInFirebase(location)
                    updateNotification(location)
                }
            }
            
            override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                super.onLocationAvailability(locationAvailability)
                Log.d(TAG, "Location availability: ${locationAvailability.isLocationAvailable}")
            }
        }
    }
    
    private fun startLocationUpdates() {
        if (isLocationUpdatesActive) return
        
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            isLocationUpdatesActive = true
            Log.d(TAG, "Location updates started")
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Location permission not granted", securityException)
        }
    }
    
    private fun stopLocationUpdates() {
        if (!isLocationUpdatesActive) return
        
        fusedLocationClient.removeLocationUpdates(locationCallback)
        isLocationUpdatesActive = false
        Log.d(TAG, "Location updates stopped")
    }
    
    private fun updateLocationInFirebase(location: Location) {
        userId?.let { uid ->
            try {
                val database = FirebaseDatabase.getInstance()
                val locationRef = database.getReference("locations").child(uid)
                
                val locationData = mapOf(
                    "lat" to location.latitude,
                    "lng" to location.longitude,
                    "accuracy" to location.accuracy,
                    "timestamp" to System.currentTimeMillis(),
                    "isSharing" to true,
                    "source" to "background_service"
                )
                
                locationRef.setValue(locationData)
                    .addOnSuccessListener {
                        Log.d(TAG, "Location updated in Firebase successfully")
                    }
                    .addOnFailureListener { exception: Exception ->
                        Log.e(TAG, "Failed to update location in Firebase", exception)
                    }
                
                // Also update user status
                val userRef = database.getReference("users").child(uid)
                userRef.updateChildren(mapOf(
                    "lastLocationUpdate" to System.currentTimeMillis(),
                    "locationSharingEnabled" to true,
                    "appUninstalled" to false
                ))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating location in Firebase", e)
            }
        }
    }
    
    private fun updateNotification(location: Location) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Last update: ${Date()}")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun startHeartbeat() {
        stopHeartbeat() // Stop any existing timer
        
        heartbeatTimer = Timer()
        heartbeatTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                sendHeartbeat()
            }
        }, 0, 30000) // Every 30 seconds
    }
    
    private fun stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = null
    }
    
    private fun sendHeartbeat() {
        userId?.let { uid ->
            try {
                val database = FirebaseDatabase.getInstance()
                val userRef = database.getReference("users").child(uid)
                
                userRef.updateChildren(mapOf(
                    "lastHeartbeat" to System.currentTimeMillis(),
                    "appUninstalled" to false,
                    "serviceActive" to true
                ))
                
                Log.d(TAG, "Heartbeat sent")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending heartbeat", e)
            }
        }
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GroupSharing::BackgroundLocationWakeLock"
            )
            wakeLock?.acquire(10*60*1000L /*10 minutes*/)
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock", e)
        }
    }
    
    private fun saveServiceState(isRunning: Boolean, userId: String?) {
        try {
            val prefs = getSharedPreferences("location_sharing_prefs", Context.MODE_PRIVATE)
            with(prefs.edit()) {
                putBoolean("location_sharing_enabled", isRunning)
                if (userId != null) {
                    putString("user_id", userId)
                } else {
                    remove("user_id")
                }
                putLong("last_update", System.currentTimeMillis())
                apply()
            }
            Log.d(TAG, "Service state saved: running=$isRunning, userId=${userId?.substring(0, 8) ?: "null"}")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving service state", e)
        }
    }
    
    private fun scheduleLocationWork() {
        // This would integrate with WorkManager for additional reliability
        // For now, we rely on the service restart mechanism
        Log.d(TAG, "Location work scheduled (service-based)")
    }
}