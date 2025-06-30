package com.sundeep.groupsharing

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.*
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Bulletproof Background Location Service for Android
 * 
 * This native service provides the most reliable background location tracking
 * by implementing multiple layers of protection against Android's aggressive
 * battery optimization and service killing.
 */
class BulletproofLocationService : Service(), LocationListener {
    
    companion object {
        private const val TAG = "BulletproofLocationService"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "bulletproof_location_channel"
        private const val LOCATION_UPDATE_INTERVAL = 15000L // 15 seconds
        private const val LOCATION_FASTEST_INTERVAL = 5000L // 5 seconds
        private const val LOCATION_DISTANCE_FILTER = 10f // 10 meters
        
        // Service state
        private var isServiceRunning = false
        private var methodChannel: MethodChannel? = null
        
        @JvmStatic
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        @JvmStatic
        fun isRunning(): Boolean = isServiceRunning
    }
    
    // Location tracking components
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationManager: LocationManager
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var notificationManager: NotificationManager
    
    // Service configuration
    private var userId: String? = null
    private var updateInterval: Long = LOCATION_UPDATE_INTERVAL
    private var distanceFilter: Float = LOCATION_DISTANCE_FILTER
    private var enableHighAccuracy: Boolean = true
    private var enablePersistentMode: Boolean = true
    
    // Health monitoring
    private var lastLocationTime: Long = 0
    private var consecutiveFailures: Int = 0
    private val maxConsecutiveFailures = 3
    private val healthCheckInterval = 30000L // 30 seconds
    private var healthCheckTimer: Timer? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "BulletproofLocationService created")
        
        initializeService()
        createNotificationChannel()
        acquireWakeLock()
        setupLocationTracking()
        startHealthMonitoring()
        
        isServiceRunning = true
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "BulletproofLocationService started")
        
        // Extract configuration from intent
        intent?.let { extractConfiguration(it) }
        
        // Start foreground service with persistent notification
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Start location tracking
        startLocationTracking()
        
        // Notify Flutter that service started
        notifyFlutter("onServiceStarted", null)
        
        // Return START_STICKY to ensure service restarts if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "BulletproofLocationService destroyed")
        
        stopLocationTracking()
        stopHealthMonitoring()
        releaseWakeLock()
        
        isServiceRunning = false
        
        // Notify Flutter that service stopped
        notifyFlutter("onServiceStopped", null)
        
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed - restarting service")
        
        // Restart the service when task is removed
        val restartServiceIntent = Intent(applicationContext, BulletproofLocationService::class.java)
        restartServiceIntent.setPackage(packageName)
        
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmService = applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            restartServicePendingIntent
        )
        
        super.onTaskRemoved(rootIntent)
    }
    
    private fun initializeService() {
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }
    
    private fun extractConfiguration(intent: Intent) {
        userId = intent.getStringExtra("userId")
        updateInterval = intent.getLongExtra("updateInterval", LOCATION_UPDATE_INTERVAL)
        distanceFilter = intent.getFloatExtra("distanceFilter", LOCATION_DISTANCE_FILTER)
        enableHighAccuracy = intent.getBooleanExtra("enableHighAccuracy", true)
        enablePersistentMode = intent.getBooleanExtra("enablePersistentMode", true)
        
        Log.d(TAG, "Configuration: userId=$userId, interval=$updateInterval, filter=$distanceFilter")
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$TAG::WakeLock"
            )
            wakeLock.acquire(10 * 60 * 1000L) // 10 minutes
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            if (::wakeLock.isInitialized && wakeLock.isHeld) {
                wakeLock.release()
                Log.d(TAG, "Wake lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bulletproof Location Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Provides reliable background location tracking"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Sharing your location with family and friends")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    private fun setupLocationTracking() {
        // Setup Google Play Services location request
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, updateInterval)
            .setMinUpdateIntervalMillis(LOCATION_FASTEST_INTERVAL)
            .setMinUpdateDistanceMeters(distanceFilter)
            .setMaxUpdateDelayMillis(updateInterval * 2)
            .build()
        
        // Setup location callback
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    handleLocationUpdate(location)
                }
            }
            
            override fun onLocationAvailability(locationAvailability: LocationAvailability) {
                if (!locationAvailability.isLocationAvailable) {
                    Log.w(TAG, "Location not available")
                    handleLocationError("Location not available")
                }
            }
        }
    }
    
    private fun startLocationTracking() {
        try {
            // Check permissions
            if (!hasLocationPermissions()) {
                Log.e(TAG, "Location permissions not granted")
                notifyFlutter("onError", "Location permissions not granted")
                return
            }
            
            // Start Google Play Services location updates
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            
            // Also register with system LocationManager as backup
            if (enablePersistentMode) {
                startSystemLocationTracking()
            }
            
            Log.d(TAG, "Location tracking started")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting location tracking", e)
            notifyFlutter("onError", "Security exception: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting location tracking", e)
            notifyFlutter("onError", "Failed to start location tracking: ${e.message}")
        }
    }
    
    private fun startSystemLocationTracking() {
        try {
            if (hasLocationPermissions()) {
                // Request updates from both GPS and Network providers
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    locationManager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        updateInterval,
                        distanceFilter,
                        this
                    )
                }
                
                if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    locationManager.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        updateInterval,
                        distanceFilter,
                        this
                    )
                }
                
                Log.d(TAG, "System location tracking started")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting system location tracking", e)
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting system location tracking", e)
        }
    }
    
    private fun stopLocationTracking() {
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
            locationManager.removeUpdates(this)
            Log.d(TAG, "Location tracking stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Exception stopping location tracking", e)
        }
    }
    
    private fun handleLocationUpdate(location: Location) {
        try {
            lastLocationTime = System.currentTimeMillis()
            consecutiveFailures = 0
            
            Log.d(TAG, "Location update: ${location.latitude}, ${location.longitude}")
            
            // Notify Flutter about location update
            val locationData = mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy.toDouble(),
                "timestamp" to System.currentTimeMillis(),
                "provider" to (location.provider ?: "unknown")
            )
            
            notifyFlutter("onLocationUpdate", locationData)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error handling location update", e)
            handleLocationError("Error processing location: ${e.message}")
        }
    }
    
    private fun handleLocationError(error: String) {
        consecutiveFailures++
        Log.e(TAG, "Location error (failure $consecutiveFailures): $error")
        
        if (consecutiveFailures >= maxConsecutiveFailures) {
            Log.e(TAG, "Max consecutive failures reached, attempting restart")
            restartLocationTracking()
        }
        
        notifyFlutter("onError", error)
    }
    
    private fun restartLocationTracking() {
        try {
            Log.d(TAG, "Restarting location tracking")
            stopLocationTracking()
            
            // Wait a moment before restarting
            Handler(Looper.getMainLooper()).postDelayed({
                startLocationTracking()
                consecutiveFailures = 0
            }, 2000)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting location tracking", e)
        }
    }
    
    private fun startHealthMonitoring() {
        healthCheckTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    performHealthCheck()
                }
            }, healthCheckInterval, healthCheckInterval)
        }
        Log.d(TAG, "Health monitoring started")
    }
    
    private fun stopHealthMonitoring() {
        healthCheckTimer?.cancel()
        healthCheckTimer = null
        Log.d(TAG, "Health monitoring stopped")
    }
    
    private fun performHealthCheck() {
        try {
            val currentTime = System.currentTimeMillis()
            val timeSinceLastLocation = currentTime - lastLocationTime
            
            // Check if we haven't received location updates recently
            if (lastLocationTime > 0 && timeSinceLastLocation > 120000) { // 2 minutes
                Log.w(TAG, "No location updates for ${timeSinceLastLocation / 1000} seconds")
                restartLocationTracking()
                return
            }
            
            // Check if location services are still enabled
            if (!isLocationEnabled()) {
                Log.w(TAG, "Location services disabled")
                notifyFlutter("onError", "Location services disabled")
                return
            }
            
            // Check permissions
            if (!hasLocationPermissions()) {
                Log.w(TAG, "Location permissions revoked")
                notifyFlutter("onError", "Location permissions revoked")
                return
            }
            
            Log.d(TAG, "Health check passed")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during health check", e)
        }
    }
    
    private fun hasLocationPermissions(): Boolean {
        return ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED &&
        ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun isLocationEnabled(): Boolean {
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
               locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
    
    private fun notifyFlutter(method: String, arguments: Any?) {
        try {
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod(method, arguments)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error notifying Flutter: $method", e)
        }
    }
    
    // LocationListener implementation for system location manager
    override fun onLocationChanged(location: Location) {
        handleLocationUpdate(location)
    }
    
    override fun onProviderEnabled(provider: String) {
        Log.d(TAG, "Provider enabled: $provider")
    }
    
    override fun onProviderDisabled(provider: String) {
        Log.w(TAG, "Provider disabled: $provider")
        if (provider == LocationManager.GPS_PROVIDER) {
            notifyFlutter("onError", "GPS provider disabled")
        }
    }
    
    @Deprecated("Deprecated in API level 29")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        Log.d(TAG, "Provider status changed: $provider, status: $status")
    }
}