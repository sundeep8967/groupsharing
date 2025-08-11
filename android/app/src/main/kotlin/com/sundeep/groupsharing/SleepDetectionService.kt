package com.example.groupsharing

import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Sleep Detection Service for Android
 * 
 * This service monitors device usage patterns to detect when the user is sleeping
 * or idle, allowing for intelligent adjustment of location tracking frequency.
 */
class SleepDetectionService : Service() {
    
    companion object {
        private const val TAG = "SleepDetection"
        
        // Static method channel for communication with Flutter
        @JvmField
        var methodChannel: MethodChannel? = null
        
        // Monitoring state
        private var isMonitoring = false
        private var lastScreenInteraction = 0L
        private var lastAppUsage = 0L
        
        // Executor for background tasks
        private val executor = Executors.newSingleThreadScheduledExecutor()
        
        fun startSleepMonitoring(context: Context) {
            val intent = Intent(context, SleepDetectionService::class.java).apply {
                action = "START_MONITORING"
            }
            context.startService(intent)
        }
        
        fun stopSleepMonitoring(context: Context) {
            val intent = Intent(context, SleepDetectionService::class.java).apply {
                action = "STOP_MONITORING"
            }
            context.stopService(intent)
        }
    }
    
    private lateinit var screenReceiver: ScreenStateReceiver
    private lateinit var usageStatsManager: UsageStatsManager
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize usage stats manager
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Register screen state receiver
        screenReceiver = ScreenStateReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        
        Log.d(TAG, "Sleep Detection Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_MONITORING" -> startSleepMonitoring()
            "STOP_MONITORING" -> stopSleepMonitoring()
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering screen receiver", e)
        }
        
        executor.shutdown()
        Log.d(TAG, "Sleep Detection Service destroyed")
    }
    
    private fun startSleepMonitoring() {
        if (isMonitoring) return
        
        isMonitoring = true
        Log.d(TAG, "Started sleep monitoring")
        
        // Start periodic app usage monitoring
        startAppUsageMonitoring()
        
        // Initialize last interaction times
        lastScreenInteraction = System.currentTimeMillis()
        lastAppUsage = System.currentTimeMillis()
    }
    
    private fun stopSleepMonitoring() {
        if (!isMonitoring) return
        
        isMonitoring = false
        Log.d(TAG, "Stopped sleep monitoring")
    }
    
    private fun startAppUsageMonitoring() {
        executor.scheduleAtFixedRate({
            if (isMonitoring) {
                checkAppUsage()
            }
        }, 0, 2, TimeUnit.MINUTES)
    }
    
    private fun checkAppUsage() {
        try {
            val endTime = System.currentTimeMillis()
            val startTime = endTime - (5 * 60 * 1000) // Last 5 minutes
            
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            var hasRecentUsage = false
            
            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == UsageEvents.Event.ACTIVITY_PAUSED) {
                    hasRecentUsage = true
                    lastAppUsage = event.timeStamp
                    break
                }
            }
            
            if (hasRecentUsage) {
                notifyAppUsage()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking app usage", e)
        }
    }
    
    private fun notifyScreenInteraction() {
        lastScreenInteraction = System.currentTimeMillis()
        
        // Send to Flutter on main thread
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("onScreenInteraction", mapOf(
                "timestamp" to lastScreenInteraction
            ))
        }
        
        Log.d(TAG, "Screen interaction detected")
    }
    
    private fun notifyAppUsage() {
        // Send to Flutter on main thread
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("onAppUsage", mapOf(
                "timestamp" to lastAppUsage
            ))
        }
        
        Log.d(TAG, "App usage detected")
    }
    
    /**
     * Broadcast receiver for screen state changes
     */
    inner class ScreenStateReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isMonitoring) return
            
            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> {
                    Log.d(TAG, "Screen turned on")
                    notifyScreenInteraction()
                }
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "Screen turned off")
                }
                Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "User present (unlocked)")
                    notifyScreenInteraction()
                }
            }
        }
    }
    
}