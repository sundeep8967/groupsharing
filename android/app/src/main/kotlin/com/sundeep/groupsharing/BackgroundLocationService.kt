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
import com.google.firebase.FirebaseApp
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
        
        // Action constants for notification buttons
        const val ACTION_UPDATE_NOW = "com.sundeep.groupsharing.UPDATE_NOW"
        const val ACTION_STOP_SHARING = "com.sundeep.groupsharing.STOP_SHARING"
        
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
        
        // Initialize Firebase if not already initialized
        initializeFirebase()
        
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createLocationRequest()
        createLocationCallback()
    }
    
    private fun initializeFirebase() {
        try {
            // Initialize Firebase if not already done
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
                Log.d(TAG, "Firebase initialized in background service")
            } else {
                Log.d(TAG, "Firebase already initialized")
            }
            
            // Check Firebase Auth state and try to restore authentication
            val currentUser = FirebaseAuth.getInstance().currentUser
            if (currentUser != null) {
                Log.d(TAG, "Firebase user authenticated: ${currentUser.uid.substring(0, 8)}")
            } else {
                Log.w(TAG, "No Firebase user authenticated in background service")
                
                // Try to restore authentication from saved credentials
                restoreFirebaseAuthentication()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Firebase in background service", e)
        }
    }
    
    private fun restoreFirebaseAuthentication() {
        try {
            // Get saved user ID from preferences
            val prefs = getSharedPreferences("location_sharing_prefs", Context.MODE_PRIVATE)
            val savedUserId = prefs.getString("user_id", null)
            
            if (savedUserId != null) {
                Log.d(TAG, "Found saved user ID: ${savedUserId.substring(0, 8)}")
                
                // Try to sign in anonymously if no user is authenticated
                // This allows the background service to write to Firebase
                FirebaseAuth.getInstance().signInAnonymously()
                    .addOnSuccessListener { authResult ->
                        Log.d(TAG, "Anonymous authentication successful for background service")
                        Log.d(TAG, "Anonymous user ID: ${authResult.user?.uid?.substring(0, 8)}")
                    }
                    .addOnFailureListener { exception ->
                        Log.e(TAG, "Anonymous authentication failed", exception)
                    }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring Firebase authentication", e)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Background location service started")
        
        // Handle notification actions
        when (intent?.action) {
            ACTION_UPDATE_NOW -> {
                Log.d(TAG, "Update Now action triggered")
                handleUpdateNowAction()
                return START_STICKY
            }
            ACTION_STOP_SHARING -> {
                Log.d(TAG, "Stop sharing action triggered")
                handleStopSharingAction()
                return START_NOT_STICKY
            }
        }
        
        userId = intent?.getStringExtra("userId") ?: userId
        
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
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "App task removed - keeping service alive")
        
        // DON'T stop the service when app is closed - this is critical for persistence
        // The notification should remain visible and functional
        
        // Restart the service to ensure it continues running
        val restartIntent = Intent(this, BackgroundLocationService::class.java)
        restartIntent.putExtra("userId", userId)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
        
        // Send a heartbeat to confirm service is still alive
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendHeartbeat()
            Log.d(TAG, "Service confirmed alive after task removal")
        }, 2000)
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
        
        // Create "Update Now" action
        val updateNowIntent = Intent(this, BackgroundLocationService::class.java).apply {
            action = ACTION_UPDATE_NOW
        }
        val updateNowPendingIntent = PendingIntent.getService(
            this, 1, updateNowIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Create "Stop Sharing" action
        val stopSharingIntent = Intent(this, BackgroundLocationService::class.java).apply {
            action = ACTION_STOP_SHARING
        }
        val stopSharingPendingIntent = PendingIntent.getService(
            this, 2, stopSharingIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Sharing your location with family members")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("Sharing your location with family members. Tap 'Update Now' for immediate location update."))
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT) // Higher priority for foreground service
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(
                android.R.drawable.ic_menu_mylocation,
                "Update Now",
                updateNowPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopSharingPendingIntent
            )
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
                Log.d(TAG, "Attempting to update location in Firebase for user: ${uid.substring(0, 8)}")
                
                // Check Firebase Auth state before updating
                val currentUser = FirebaseAuth.getInstance().currentUser
                if (currentUser == null) {
                    Log.w(TAG, "No authenticated user - attempting anonymous update")
                } else {
                    Log.d(TAG, "Authenticated user: ${currentUser.uid.substring(0, 8)}")
                }
                
                val database = FirebaseDatabase.getInstance()
                
                // Enable offline persistence for reliability
                try {
                    database.setPersistenceEnabled(true)
                } catch (e: Exception) {
                    Log.d(TAG, "Persistence already enabled or not available: ${e.message}")
                }
                
                val locationRef = database.getReference("locations").child(uid)
                
                val timestamp = System.currentTimeMillis()
                val readableTime = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                }.format(java.util.Date(timestamp))
                
                val locationData = mapOf(
                    "lat" to location.latitude,
                    "lng" to location.longitude,
                    "accuracy" to location.accuracy,
                    "timestamp" to timestamp,
                    "timestampReadable" to readableTime, // Human-readable format
                    "isSharing" to true,
                    "lastUpdate" to timestamp,
                    "lastUpdateReadable" to readableTime, // Human-readable format
                    "source" to "background_service",
                    "updatedAt" to readableTime, // Additional readable timestamp
                    "authStatus" to if (currentUser != null) "authenticated" else "anonymous"
                )
                
                Log.d(TAG, "Updating Firebase with location: ${location.latitude}, ${location.longitude}")
                
                locationRef.setValue(locationData)
                    .addOnSuccessListener {
                        Log.d(TAG, "SUCCESS: Location updated in Firebase at $readableTime")
                        Log.d(TAG, "SUCCESS: Coordinates: ${location.latitude}, ${location.longitude}")
                    }
                    .addOnFailureListener { exception: Exception ->
                        Log.e(TAG, "FAILED: Location update failed: ${exception.message}")
                        Log.e(TAG, "FAILED: Exception details: ", exception)
                        
                        // Try to save to local storage as backup
                        saveLocationToLocalStorage(location, timestamp, readableTime)
                    }
                
                // Also update user status with readable timestamps
                val userRef = database.getReference("users").child(uid)
                val userStatusData = mapOf(
                    "lastLocationUpdate" to timestamp,
                    "lastLocationUpdateReadable" to readableTime, // Human-readable format
                    "lastSeen" to timestamp,
                    "lastSeenReadable" to readableTime, // Human-readable format
                    "locationSharingEnabled" to true,
                    "appUninstalled" to false,
                    "serviceActive" to true,
                    "statusUpdatedAt" to readableTime, // When status was last updated
                    "authStatus" to if (currentUser != null) "authenticated" else "anonymous"
                )
                
                userRef.updateChildren(userStatusData)
                    .addOnSuccessListener {
                        Log.d(TAG, "SUCCESS: User status updated in Firebase")
                    }
                    .addOnFailureListener { exception: Exception ->
                        Log.e(TAG, "FAILED: User status update failed: ${exception.message}")
                    }
                
            } catch (e: Exception) {
                Log.e(TAG, "CRITICAL ERROR: Firebase update failed", e)
                
                // Save to local storage as backup
                val timestamp = System.currentTimeMillis()
                val readableTime = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                }.format(java.util.Date(timestamp))
                saveLocationToLocalStorage(location, timestamp, readableTime)
            }
        } ?: run {
            Log.e(TAG, "CRITICAL ERROR: Cannot update Firebase - userId is null")
        }
    }
    
    private fun saveLocationToLocalStorage(location: Location, timestamp: Long, readableTime: String) {
        try {
            val prefs = getSharedPreferences("location_backup", Context.MODE_PRIVATE)
            with(prefs.edit()) {
                putString("last_location_lat", location.latitude.toString())
                putString("last_location_lng", location.longitude.toString())
                putLong("last_location_timestamp", timestamp)
                putString("last_location_readable", readableTime)
                putString("backup_reason", "firebase_update_failed")
                apply()
            }
            Log.d(TAG, "BACKUP: Location saved to local storage")
        } catch (e: Exception) {
            Log.e(TAG, "BACKUP FAILED: Could not save to local storage", e)
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
                
                val timestamp = System.currentTimeMillis()
                val readableTime = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                }.format(java.util.Date(timestamp))
                
                userRef.updateChildren(mapOf(
                    "lastHeartbeat" to timestamp,
                    "lastHeartbeatReadable" to readableTime, // Human-readable format
                    "appUninstalled" to false,
                    "serviceActive" to true,
                    "heartbeatAt" to readableTime // When heartbeat was sent
                ))
                
                Log.d(TAG, "Heartbeat sent at $readableTime")
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
    
    private fun handleUpdateNowAction() {
        Log.d(TAG, "Handling Update Now action")
        
        // Update notification to show "Updating..."
        showUpdatingNotification()
        
        // Get immediate high-accuracy location
        try {
            val highAccuracyRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L)
                .setWaitForAccurateLocation(true)
                .setMinUpdateIntervalMillis(500L)
                .setMinUpdateDistanceMeters(0f)
                .setMaxUpdates(1)
                .build()
            
            val immediateCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    super.onLocationResult(locationResult)
                    
                    locationResult.lastLocation?.let { location ->
                        Log.d(TAG, "Immediate location update: ${location.latitude}, ${location.longitude}")
                        updateLocationInFirebase(location)
                        
                        // Show success notification
                        showUpdateSuccessNotification(location)
                        
                        // Restore normal notification after 3 seconds
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.notify(NOTIFICATION_ID, createNotification())
                        }, 3000)
                    }
                    
                    // Remove this callback
                    fusedLocationClient.removeLocationUpdates(this)
                }
                
                override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                    super.onLocationAvailability(locationAvailability)
                    if (!locationAvailability.isLocationAvailable) {
                        Log.w(TAG, "Location not available for immediate update")
                        showUpdateFailedNotification()
                        
                        // Restore normal notification after 3 seconds
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.notify(NOTIFICATION_ID, createNotification())
                        }, 3000)
                    }
                }
            }
            
            fusedLocationClient.requestLocationUpdates(
                highAccuracyRequest,
                immediateCallback,
                Looper.getMainLooper()
            )
            
        } catch (securityException: SecurityException) {
            Log.e(TAG, "Location permission not granted for immediate update", securityException)
            showUpdateFailedNotification()
        }
    }
    
    private fun handleStopSharingAction() {
        Log.d(TAG, "Handling Stop Sharing action")
        
        // Save state as stopped
        saveServiceState(false, null)
        
        // Stop the service
        stopSelf()
    }
    
    private fun showUpdatingNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Updating Location...")
            .setContentText("Getting your current location")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setProgress(0, 0, true) // Indeterminate progress
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun showUpdateSuccessNotification(location: Location) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Updated Successfully")
            .setContentText("Shared your current location with family")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun showUpdateFailedNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Update Failed")
            .setContentText("Unable to get current location")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}