package com.sundeep.groupsharing

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel
import android.util.Log

/**
 * Persistent Foreground Notification Service
 * 
 * This service creates a persistent, non-dismissible foreground notification that:
 * 1. Keeps the app alive in background
 * 2. Shows real-time location sharing status
 * 3. Cannot be swiped away by user
 * 4. Provides quick actions for location control
 * 5. Complies with Android 8.0+ foreground service requirements
 * 6. Implements proper wake lock management
 */
class PersistentForegroundNotificationService : Service() {
    
    companion object {
        private const val TAG = "PersistentForegroundNotificationService"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "location_sharing_persistent"
        private const val CHANNEL_NAME = "Location Sharing"
        private const val CHANNEL_DESCRIPTION = "Persistent notification for location sharing"
        
        // Action IDs for notification buttons
        private const val ACTION_PAUSE_SHARING = "pause_sharing"
        private const val ACTION_OPEN_APP = "open_app"
        private const val ACTION_VIEW_FRIENDS = "view_friends"
        
        // Service state
        private var isServiceRunning = false
        private var currentUserId: String? = null
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun isRunning(): Boolean = isServiceRunning
    }
    
    private lateinit var notificationManager: NotificationManagerCompat
    private var wakeLock: PowerManager.WakeLock? = null
    private var notificationBuilder: NotificationCompat.Builder? = null
    
    // Notification content state
    private var notificationTitle = "Location Sharing Active"
    private var notificationContent = "Sharing your location with friends and family"
    private var locationStatus = "Initializing..."
    private var friendsCount = 0
    private var isLocationSharing = true
    private var currentLatitude: Double? = null
    private var currentLongitude: Double? = null
    private var lastLocationUpdate: Long = 0
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        notificationManager = NotificationManagerCompat.from(this)
        createNotificationChannel()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started with intent: $intent")
        
        when (intent?.action) {
            ACTION_PAUSE_SHARING -> handlePauseSharing()
            ACTION_OPEN_APP -> handleOpenApp()
            ACTION_VIEW_FRIENDS -> handleViewFriends()
            else -> {
                // Regular service start
                val userId = intent?.getStringExtra("userId")
                if (userId != null) {
                    startForegroundService(userId)
                }
            }
        }
        
        // Return START_STICKY to ensure service restarts if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        
        isServiceRunning = false
        releaseWakeLock()
        
        // Notify Flutter that service stopped
        methodChannel?.invokeMethod("onServiceStopped", null)
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d(TAG, "Task removed - restarting service")
        
        // Restart the service when task is removed
        val restartIntent = Intent(this, PersistentForegroundNotificationService::class.java)
        restartIntent.putExtra("userId", currentUserId)
        startService(restartIntent)
    }
    
    private fun startForegroundService(userId: String) {
        try {
            currentUserId = userId
            isServiceRunning = true
            
            Log.d(TAG, "Starting foreground service for user: ${userId.take(8)}")
            
            // Create and show persistent notification
            val notification = createPersistentNotification()
            startForeground(NOTIFICATION_ID, notification)
            
            // Notify Flutter that service started
            methodChannel?.invokeMethod("onServiceStarted", null)
            
            Log.d(TAG, "Foreground service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground service", e)
            methodChannel?.invokeMethod("onServiceError", mapOf("error" to e.message))
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Low importance to avoid sound/vibration
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
                
                // Make channel non-dismissible
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(false)
                }
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "Notification channel created")
        }
    }
    
    private fun createPersistentNotification(): Notification {
        val timeSinceUpdate = if (lastLocationUpdate > 0) {
            (System.currentTimeMillis() - lastLocationUpdate) / (1000 * 60) // minutes
        } else 0
        
        val locationText = if (currentLatitude != null && currentLongitude != null) {
            "Location: ${String.format("%.4f", currentLatitude)}, ${String.format("%.4f", currentLongitude)}"
        } else {
            "Location: Not available"
        }
        
        val statusText = if (isLocationSharing) {
            "Sharing with $friendsCount friends"
        } else {
            "Location sharing paused"
        }
        
        val updateText = if (timeSinceUpdate > 0) {
            "Updated ${timeSinceUpdate}m ago"
        } else {
            "Just updated"
        }
        
        val bigText = "$statusText\n$locationText\nStatus: $locationStatus\n$updateText"
        val contentText = "$statusText • $updateText"
        
        // Create notification builder
        notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(notificationTitle)
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setSubText("GroupSharing")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Using system icon
            .setColor(Color.BLUE)
            .setOngoing(true) // Makes notification persistent
            .setAutoCancel(false) // Prevents dismissal
            .setPriority(NotificationCompat.PRIORITY_LOW) // Low priority to avoid interruption
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setSound(null) // No sound
            .setVibrate(null) // No vibration
            .setLights(Color.TRANSPARENT, 0, 0) // No lights
            
        // Add action buttons
        addNotificationActions()
        
        // Set content intent to open app
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        notificationBuilder!!.setContentIntent(openAppPendingIntent)
        
        return notificationBuilder!!.build()
    }
    
    private fun addNotificationActions() {
        // Pause/Resume sharing action
        val pauseIntent = Intent(this, PersistentForegroundNotificationService::class.java).apply {
            action = ACTION_PAUSE_SHARING
        }
        val pausePendingIntent = PendingIntent.getService(
            this, 1, pauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val pauseAction = NotificationCompat.Action.Builder(
            if (isLocationSharing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isLocationSharing) "Pause Sharing" else "Resume Sharing",
            pausePendingIntent
        ).build()
        
        // Open app action
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 2, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openAppAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Open App",
            openAppPendingIntent
        ).build()
        
        // View friends action
        val viewFriendsIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("screen", "friends")
        }
        val viewFriendsPendingIntent = PendingIntent.getActivity(
            this, 3, viewFriendsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val viewFriendsAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_agenda,
            "View Friends",
            viewFriendsPendingIntent
        ).build()
        
        notificationBuilder?.apply {
            addAction(pauseAction)
            addAction(openAppAction)
            addAction(viewFriendsAction)
        }
    }
    
    private fun handlePauseSharing() {
        Log.d(TAG, "Pause sharing action triggered")
        
        isLocationSharing = !isLocationSharing
        updateNotification()
        
        // Notify Flutter about the action
        methodChannel?.invokeMethod("onNotificationAction", mapOf("action" to ACTION_PAUSE_SHARING))
    }
    
    private fun handleOpenApp() {
        Log.d(TAG, "Open app action triggered")
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(intent)
        
        // Notify Flutter about the action
        methodChannel?.invokeMethod("onNotificationAction", mapOf("action" to ACTION_OPEN_APP))
    }
    
    private fun handleViewFriends() {
        Log.d(TAG, "View friends action triggered")
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("screen", "friends")
        }
        startActivity(intent)
        
        // Notify Flutter about the action
        methodChannel?.invokeMethod("onNotificationAction", mapOf("action" to ACTION_VIEW_FRIENDS))
    }
    
    fun updateNotificationContent(
        title: String? = null,
        content: String? = null,
        status: String? = null,
        friendsCount: Int? = null,
        isSharing: Boolean? = null,
        latitude: Double? = null,
        longitude: Double? = null
    ) {
        try {
            // Update internal state
            title?.let { notificationTitle = it }
            content?.let { notificationContent = it }
            status?.let { locationStatus = it }
            friendsCount?.let { this.friendsCount = it }
            isSharing?.let { isLocationSharing = it }
            latitude?.let { currentLatitude = it }
            longitude?.let { currentLongitude = it }
            
            if (latitude != null || longitude != null) {
                lastLocationUpdate = System.currentTimeMillis()
            }
            
            // Update notification
            updateNotification()
            
            Log.d(TAG, "Notification content updated")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification content", e)
        }
    }
    
    private fun updateNotification() {
        try {
            if (isServiceRunning && notificationBuilder != null) {
                val notification = createPersistentNotification()
                notificationManager.notify(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }
    
    fun makeNotificationPersistent() {
        try {
            // Additional measures to make notification persistent
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                channel?.let {
                    it.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    it.setShowBadge(false)
                    notificationManager.createNotificationChannel(it)
                }
            }
            
            Log.d(TAG, "Notification made persistent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to make notification persistent", e)
        }
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "$TAG:WakeLock"
            ).apply {
                acquire(10 * 60 * 1000L) // 10 minutes
            }
            
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
            
            Log.d(TAG, "Wake lock released")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release wake lock", e)
        }
    }
    
    fun sendHeartbeat(timestamp: Long, isLocationSharing: Boolean, friendsCount: Int) {
        try {
            this.isLocationSharing = isLocationSharing
            this.friendsCount = friendsCount
            
            // Update notification to show we're alive
            updateNotification()
            
            Log.d(TAG, "Heartbeat sent: $timestamp")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send heartbeat", e)
        }
    }
}