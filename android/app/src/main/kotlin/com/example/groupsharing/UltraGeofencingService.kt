package com.example.groupsharing

import android.Manifest
import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.android.gms.tasks.OnCompleteListener
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit

/**
 * Ultra-Active Geofencing Service for Android
 * This service provides military-grade location tracking that survives:
 * - App termination
 * - Phone restart (with auto-start)
 * - Battery optimization
 * - Doze mode
 */
class UltraGeofencingService : Service() {
    
    companion object {
        private const val TAG = "UltraGeofencing"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "ultra_geofencing_channel"
        private const val LOCATION_UPDATE_INTERVAL = 5000L // 5 seconds
        private const val FASTEST_UPDATE_INTERVAL = 2000L // 2 seconds
        private const val GEOFENCE_RADIUS = 5.0f // 5 meters
        private const val GEOFENCE_EXPIRATION = 24 * 60 * 60 * 1000L // 24 hours
        
        var isRunning = false
        var methodChannel: MethodChannel? = null
    }
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    private lateinit var geofencingClient: GeofencingClient
    private lateinit var wakeLock: PowerManager.WakeLock
    
    private var currentUserId: String? = null
    private var isUltraActive = false
    private val activeGeofences = mutableMapOf<String, Geofence>()
    private var lastKnownLocation: Location? = null
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize location services
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        geofencingClient = LocationServices.getGeofencingClient(this)
        
        // Create notification channel
        createNotificationChannel()
        
        // Acquire wake lock to prevent doze mode
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "UltraGeofencing::WakeLock"
        )
        
        // Setup location request for ultra-high precision
        locationRequest = LocationRequest.create().apply {
            interval = LOCATION_UPDATE_INTERVAL
            fastestInterval = FASTEST_UPDATE_INTERVAL
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            smallestDisplacement = GEOFENCE_RADIUS // Only update if moved 5+ meters
        }
        
        // Setup location callback
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                handleLocationUpdate(locationResult.lastLocation)
            }
        }
        
        isRunning = true
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val userId = intent?.getStringExtra("userId")
        val ultraActive = intent?.getBooleanExtra("ultraActive", false) ?: false
        
        if (userId != null) {
            startUltraTracking(userId, ultraActive)
        }
        
        // Return START_STICKY to restart service if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun startUltraTracking(userId: String, ultraActive: Boolean) {
        currentUserId = userId
        isUltraActive = ultraActive
        
        // Start foreground service with persistent notification
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Acquire wake lock
        if (!wakeLock.isHeld) {
            wakeLock.acquire(TimeUnit.HOURS.toMillis(24)) // 24 hours
        }
        
        // Request location updates
        startLocationUpdates()
        
        // Setup geofencing
        setupGeofencing()
    }
    
    private fun startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        
        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback,
            null
        )
    }
    
    private fun handleLocationUpdate(location: Location?) {
        location ?: return
        
        // Check if location changed by 5+ meters
        lastKnownLocation?.let { lastLocation ->
            val distance = location.distanceTo(lastLocation)
            if (distance < GEOFENCE_RADIUS) {
                return // Location hasn't changed significantly
            }
        }
        
        lastKnownLocation = location
        
        // Process geofences
        processGeofences(location)
        
        // Send location update to Flutter
        sendLocationUpdate(location)
        
        // Update notification with current location
        updateNotification(location)
    }
    
    private fun processGeofences(location: Location) {
        for ((geofenceId, geofence) in activeGeofences) {
            val geofenceLocation = Location("").apply {
                latitude = geofence.latitude
                longitude = geofence.longitude
            }
            
            val distance = location.distanceTo(geofenceLocation)
            val isInside = distance <= geofence.radius
            
            // Send geofence event to Flutter
            sendGeofenceEvent(geofenceId, isInside)
        }
    }
    
    private fun sendLocationUpdate(location: Location) {
        methodChannel?.invokeMethod("onLocationUpdate", mapOf(
            "lat" to location.latitude,
            "lng" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    private fun sendGeofenceEvent(geofenceId: String, entered: Boolean) {
        methodChannel?.invokeMethod("onGeofenceEvent", mapOf(
            "geofenceId" to geofenceId,
            "entered" to entered,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    fun addGeofence(id: String, lat: Double, lng: Double, radius: Float, name: String) {
        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(lat, lng, radius)
            .setExpirationDuration(GEOFENCE_EXPIRATION)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()
        
        activeGeofences[id] = geofence
        
        // Register with Android geofencing API
        val geofencingRequest = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()
        
        val geofencePendingIntent = createGeofencePendingIntent()
        
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            geofencingClient.addGeofences(geofencingRequest, geofencePendingIntent)
        }
    }
    
    private fun createGeofencePendingIntent(): PendingIntent {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
    
    private fun setupGeofencing() {
        // Geofencing setup will be done when geofences are added
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ultra Geofencing Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Provides ultra-precise location tracking and geofencing"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ultra Geofencing Active")
            .setContentText("Tracking location with 5-meter precision")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun updateNotification(location: Location) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ultra Geofencing Active")
            .setContentText("Location: ${String.format("%.6f", location.latitude)}, ${String.format("%.6f", location.longitude)}")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Release wake lock
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
        
        // Stop location updates
        fusedLocationClient.removeLocationUpdates(locationCallback)
        
        // Remove geofences
        geofencingClient.removeGeofences(createGeofencePendingIntent())
        
        isRunning = false
        
        // Restart service if it was killed unexpectedly
        if (currentUserId != null) {
            val restartIntent = Intent(this, UltraGeofencingService::class.java).apply {
                putExtra("userId", currentUserId)
                putExtra("ultraActive", isUltraActive)
            }
            startService(restartIntent)
        }
    }
}

/**
 * Broadcast receiver for geofence events
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent?.hasError() == true) {
            return
        }
        
        val geofenceTransition = geofencingEvent?.geofenceTransition ?: return
        val triggeringGeofences = geofencingEvent.triggeringGeofences ?: return
        
        for (geofence in triggeringGeofences) {
            val entered = geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER
            
            UltraGeofencingService.methodChannel?.invokeMethod("onGeofenceEvent", mapOf(
                "geofenceId" to geofence.requestId,
                "entered" to entered,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }
}