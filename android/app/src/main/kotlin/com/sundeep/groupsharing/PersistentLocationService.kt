package com.sundeep.groupsharing

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import com.google.android.gms.location.*
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.auth.FirebaseAuth
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * Ultra-Persistent Location Service designed specifically for OnePlus devices
 * This service uses multiple strategies to survive aggressive battery optimization:
 * 1. Foreground service with persistent notification
 * 2. Partial wake lock to prevent doze mode
 * 3. WorkManager backup for service resurrection
 * 4. Multiple restart mechanisms
 * 5. Heartbeat system to detect service death
 * 6. Aggressive restart on service destruction
 */
class PersistentLocationService : Service() {
    
    companion object {
        private const val TAG = "PersistentLocationService"
        private const val NOTIFICATION_ID = 12346
        private const val CHANNEL_ID = "persistent_location_channel"
        private const val LOCATION_UPDATE_INTERVAL = 10000L // 10 seconds for OnePlus
        private const val FASTEST_LOCATION_INTERVAL = 5000L // 5 seconds
        private const val LOCATION_DISTANCE_THRESHOLD = 5f // 5 meters for better accuracy
        private const val HEARTBEAT_INTERVAL = 15000L // 15 seconds heartbeat
        private const val RESTART_DELAY = 5000L // 5 seconds restart delay
        
        const val EXTRA_USER_ID = "userId"
        const val ACTION_START_PERSISTENT = "START_PERSISTENT"
        const val ACTION_STOP_PERSISTENT = "STOP_PERSISTENT"
        const val ACTION_RESTART_SERVICE = "RESTART_SERVICE"
        
        // Shared preferences keys
        private const val PREFS_NAME = "persistent_location_prefs"
        private const val KEY_SERVICE_ENABLED = "service_enabled"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat"
        private const val KEY_RESTART_COUNT = "restart_count"
        
        @JvmStatic
        fun startPersistentService(context: Context, userId: String) {
            Log.d(TAG, "Starting persistent location service for user: ${userId.substring(0, 8)}")
            
            // Save state immediately
            saveServiceState(context, true, userId)
            
            val intent = Intent(context, PersistentLocationService::class.java).apply {
                action = ACTION_START_PERSISTENT
                putExtra(EXTRA_USER_ID, userId)
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                
                // Schedule WorkManager backup
                scheduleLocationWork(context, userId)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error starting persistent service", e)
                // Try alternative start method
                try {
                    context.startService(intent)
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to start service with fallback method", e2)
                }
            }
        }
        
        @JvmStatic
        fun stopPersistentService(context: Context) {
            Log.d(TAG, "Stopping persistent location service")
            
            // Save state
            saveServiceState(context, false, null)
            
            val intent = Intent(context, PersistentLocationService::class.java).apply {
                action = ACTION_STOP_PERSISTENT
            }
            
            context.stopService(intent)
            
            // Cancel WorkManager backup
            WorkManager.getInstance(context).cancelUniqueWork("location_backup")
        }
        
        fun restartService(context: Context) {
            Log.d(TAG, "Restarting persistent location service")
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
            val userId = prefs.getString(KEY_USER_ID, null)
            
            if (isEnabled && !userId.isNullOrEmpty()) {
                // Increment restart count
                val restartCount = prefs.getInt(KEY_RESTART_COUNT, 0) + 1
                prefs.edit().putInt(KEY_RESTART_COUNT, restartCount).apply()
                
                Log.d(TAG, "Restarting service (attempt #$restartCount) for user: ${userId.substring(0, 8)}")
                
                // Delay restart to avoid rapid restart loops
                Timer().schedule(object : TimerTask() {
                    override fun run() {
                        startPersistentService(context, userId)
                    }
                }, RESTART_DELAY)
            }
        }
        
        private fun saveServiceState(context: Context, isEnabled: Boolean, userId: String?) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                with(prefs.edit()) {
                    putBoolean(KEY_SERVICE_ENABLED, isEnabled)
                    if (userId != null) {
                        putString(KEY_USER_ID, userId)
                    } else {
                        remove(KEY_USER_ID)
                    }
                    putLong(KEY_LAST_HEARTBEAT, System.currentTimeMillis())
                    apply()
                }
                Log.d(TAG, "Service state saved: enabled=$isEnabled, userId=${userId?.substring(0, 8) ?: "null"}")
            } catch (e: Exception) {
                Log.e(TAG, "Error saving service state", e)
            }
        }
        
        private fun scheduleLocationWork(context: Context, userId: String) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(false) // Don't require high battery
                .build()
            
            val locationWork = PeriodicWorkRequestBuilder<LocationBackupWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setInputData(workDataOf("userId" to userId))
                .setBackoffCriteria(BackoffPolicy.LINEAR, 5, TimeUnit.MINUTES)
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "location_backup",
                ExistingPeriodicWorkPolicy.REPLACE,
                locationWork
            )
            
            Log.d(TAG, "Location backup work scheduled")
        }
        
        @JvmStatic
        fun isServiceRunning(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastHeartbeat = prefs.getLong(KEY_LAST_HEARTBEAT, 0)
            val currentTime = System.currentTimeMillis()
            
            // Consider service running if heartbeat is within last 2 minutes
            return (currentTime - lastHeartbeat) < 120000
        }
    }
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    private var userId: String? = null
    private var isLocationUpdatesActive = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var heartbeatTimer: Timer? = null
    private var restartTimer: Timer? = null
    private var notificationManager: NotificationManager? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Persistent location service created")
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createLocationRequest()
        createLocationCallback()
        
        // Start as foreground service immediately
        startForeground(NOTIFICATION_ID, createNotification("Initializing location service..."))
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Persistent location service onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_PERSISTENT -> {
                userId = intent.getStringExtra(EXTRA_USER_ID)
                if (userId.isNullOrEmpty()) {
                    Log.e(TAG, "No user ID provided, stopping service")
                    stopSelf()
                    return START_NOT_STICKY
                }
                
                startPersistentLocationTracking()
            }
            ACTION_STOP_PERSISTENT -> {
                stopPersistentLocationTracking()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_RESTART_SERVICE -> {
                Log.d(TAG, "Service restart requested")
                restartLocationTracking()
            }
            else -> {
                // Handle service restart by system
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val savedUserId = prefs.getString(KEY_USER_ID, null)
                val isEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
                
                if (isEnabled && !savedUserId.isNullOrEmpty()) {
                    userId = savedUserId
                    Log.d(TAG, "Service restarted by system, resuming for user: ${userId!!.substring(0, 8)}")
                    startPersistentLocationTracking()
                } else {
                    Log.d(TAG, "Service restarted but no saved state found")
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
        }
        
        // Return START_STICKY for maximum persistence
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Persistent location service destroyed")
        
        // Clean up resources
        stopLocationUpdates()
        releaseWakeLock()
        stopHeartbeat()
        stopRestartTimer()
        
        // Check if service should restart
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
        
        if (isEnabled) {
            Log.d(TAG, "Service destroyed but should be running - scheduling restart")
            scheduleServiceRestart()
        }
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed - ensuring service continues")
        
        // OnePlus devices often kill services when task is removed
        // Schedule immediate restart
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
        
        if (isEnabled) {
            scheduleServiceRestart()
        }
    }
    
    private fun startPersistentLocationTracking() {
        Log.d(TAG, "Starting persistent location tracking for user: ${userId!!.substring(0, 8)}")
        
        // Update notification
        updateNotification("Starting location tracking...")
        
        // Acquire wake lock
        acquireWakeLock()
        
        // Start location updates
        startLocationUpdates()
        
        // Start heartbeat
        startHeartbeat()
        
        // Start restart monitoring
        startRestartMonitoring()
        
        // Update notification
        updateNotification("Location tracking active")
        
        Log.d(TAG, "Persistent location tracking fully initialized")
    }
    
    private fun stopPersistentLocationTracking() {
        Log.d(TAG, "Stopping persistent location tracking")
        
        stopLocationUpdates()
        releaseWakeLock()
        stopHeartbeat()
        stopRestartTimer()
        
        // Clear saved state
        saveServiceState(this, false, null)
    }
    
    private fun restartLocationTracking() {
        Log.d(TAG, "Restarting location tracking")
        
        stopLocationUpdates()
        startLocationUpdates()
        
        // Reset heartbeat
        stopHeartbeat()
        startHeartbeat()
        
        updateNotification("Location tracking restarted")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Persistent Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuously tracks your location for family sharing"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(contentText: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GroupSharing Location")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(false)
            .setAutoCancel(false)
            .build()
    }
    
    private fun updateNotification(contentText: String) {
        try {
            val notification = createNotification(contentText)
            notificationManager?.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating notification", e)
        }
    }
    
    private fun createLocationRequest() {
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, LOCATION_UPDATE_INTERVAL)
            .setWaitForAccurateLocation(false)
            .setMinUpdateIntervalMillis(FASTEST_LOCATION_INTERVAL)
            .setMinUpdateDistanceMeters(LOCATION_DISTANCE_THRESHOLD)
            .setMaxUpdateDelayMillis(LOCATION_UPDATE_INTERVAL * 2)
            .build()
    }
    
    private fun createLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "New location: ${location.latitude}, ${location.longitude} (accuracy: ${location.accuracy}m)")
                    updateLocationInFirebase(location)
                    updateNotification("Last update: ${Date().toString().substring(11, 19)}")
                }
            }
            
            override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                super.onLocationAvailability(locationAvailability)
                Log.d(TAG, "Location availability: ${locationAvailability.isLocationAvailable}")
                
                if (!locationAvailability.isLocationAvailable) {
                    updateNotification("Location unavailable - retrying...")
                    // Try to restart location updates
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            if (!isLocationUpdatesActive) {
                                startLocationUpdates()
                            }
                        }
                    }, 5000)
                }
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
            updateNotification("Location permission denied")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting location updates", e)
            updateNotification("Location error - retrying...")
        }
    }
    
    private fun stopLocationUpdates() {
        if (!isLocationUpdatesActive) return
        
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
            isLocationUpdatesActive = false
            Log.d(TAG, "Location updates stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping location updates", e)
        }
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
                    "source" to "persistent_service",
                    "speed" to if (location.hasSpeed()) location.speed else 0.0,
                    "bearing" to if (location.hasBearing()) location.bearing else 0.0,
                    "altitude" to if (location.hasAltitude()) location.altitude else 0.0
                )
                
                locationRef.setValue(locationData)
                    .addOnSuccessListener {
                        Log.d(TAG, "Location updated in Firebase successfully")
                    }
                    .addOnFailureListener { exception ->
                        Log.e(TAG, "Failed to update location in Firebase", exception)
                    }
                
                // Update user status
                val userRef = database.getReference("users").child(uid)
                userRef.updateChildren(mapOf(
                    "lastLocationUpdate" to System.currentTimeMillis(),
                    "locationSharingEnabled" to true,
                    "appUninstalled" to false,
                    "serviceActive" to true,
                    "lastHeartbeat" to System.currentTimeMillis()
                ))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error updating location in Firebase", e)
            }
        }
    }
    
    private fun startHeartbeat() {
        stopHeartbeat()
        
        heartbeatTimer = Timer()
        heartbeatTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                sendHeartbeat()
            }
        }, 0, HEARTBEAT_INTERVAL)
        
        Log.d(TAG, "Heartbeat started")
    }
    
    private fun stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = null
    }
    
    private fun sendHeartbeat() {
        try {
            // Update local preferences
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putLong(KEY_LAST_HEARTBEAT, System.currentTimeMillis()).apply()
            
            // Update Firebase
            userId?.let { uid ->
                val database = FirebaseDatabase.getInstance()
                val userRef = database.getReference("users").child(uid)
                
                userRef.updateChildren(mapOf(
                    "lastHeartbeat" to System.currentTimeMillis(),
                    "appUninstalled" to false,
                    "serviceActive" to true,
                    "persistentServiceRunning" to true
                ))
            }
            
            Log.d(TAG, "Heartbeat sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending heartbeat", e)
        }
    }
    
    private fun startRestartMonitoring() {
        stopRestartTimer()
        
        restartTimer = Timer()
        restartTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkServiceHealth()
            }
        }, 60000, 60000) // Check every minute
        
        Log.d(TAG, "Restart monitoring started")
    }
    
    private fun stopRestartTimer() {
        restartTimer?.cancel()
        restartTimer = null
    }
    
    private fun checkServiceHealth() {
        try {
            if (!isLocationUpdatesActive) {
                Log.w(TAG, "Location updates not active - restarting")
                startLocationUpdates()
            }
            
            if (wakeLock?.isHeld != true) {
                Log.w(TAG, "Wake lock not held - reacquiring")
                acquireWakeLock()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking service health", e)
        }
    }
    
    private fun acquireWakeLock() {
        try {
            releaseWakeLock() // Release any existing wake lock
            
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GroupSharing::PersistentLocationWakeLock"
            )
            wakeLock?.acquire(10*60*1000L) // 10 minutes
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
    
    private fun scheduleServiceRestart() {
        Log.d(TAG, "Scheduling service restart")
        
        // Use WorkManager for reliable restart
        val restartWork = OneTimeWorkRequestBuilder<ServiceRestartWorker>()
            .setInitialDelay(RESTART_DELAY, TimeUnit.MILLISECONDS)
            .build()
        
        WorkManager.getInstance(this).enqueue(restartWork)
    }
    
    private fun saveServiceState(context: Context, isEnabled: Boolean, userId: String?) {
        Companion.saveServiceState(context, isEnabled, userId)
    }
}

/**
 * WorkManager worker for location backup
 */
class LocationBackupWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    
    override fun doWork(): Result {
        Log.d("LocationBackupWorker", "Location backup work started")
        
        try {
            val userId = inputData.getString("userId")
            if (userId.isNullOrEmpty()) {
                return Result.failure()
            }
            
            // Check if main service is running
            if (!PersistentLocationService.isServiceRunning(applicationContext)) {
                Log.w("LocationBackupWorker", "Main service not running - restarting")
                PersistentLocationService.restartService(applicationContext)
            }
            
            return Result.success()
            
        } catch (e: Exception) {
            Log.e("LocationBackupWorker", "Error in location backup work", e)
            return Result.retry()
        }
    }
}

/**
 * WorkManager worker for service restart
 */
class ServiceRestartWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    
    override fun doWork(): Result {
        Log.d("ServiceRestartWorker", "Service restart work started")
        
        try {
            PersistentLocationService.restartService(applicationContext)
            return Result.success()
        } catch (e: Exception) {
            Log.e("ServiceRestartWorker", "Error restarting service", e)
            return Result.failure()
        }
    }
}