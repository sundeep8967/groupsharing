package com.sundeep.groupsharing

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Bulletproof Permission Helper
 * 
 * This class handles all permission-related operations for the bulletproof location service,
 * including Android 12+ restrictions and device-specific permission handling.
 */
object BulletproofPermissionHelper {
    
    private const val TAG = "BulletproofPermissionHelper"
    
    /**
     * Check if all required permissions are granted
     */
    fun hasAllRequiredPermissions(context: Context): Boolean {
        return hasLocationPermissions(context) &&
               hasBackgroundLocationPermission(context) &&
               hasNotificationPermission(context) &&
               hasExactAlarmPermission(context)
    }
    
    /**
     * Check if basic location permissions are granted
     */
    fun hasLocationPermissions(context: Context): Boolean {
        val fineLocation = ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        
        val coarseLocation = ContextCompat.checkSelfPermission(
            context, 
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        
        return fineLocation && coarseLocation
    }
    
    /**
     * Check if background location permission is granted
     */
    fun hasBackgroundLocationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context, 
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required for Android < Q
        }
    }
    
    /**
     * Check if notification permission is granted (Android 13+)
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, 
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required for Android < 13
        }
    }
    
    /**
     * Check if exact alarm permission is granted (Android 12+)
     */
    fun hasExactAlarmPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.canScheduleExactAlarms()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check exact alarm permission", e)
                false
            }
        } else {
            true // Not required for Android < 12
        }
    }
    
    /**
     * Request background location permission
     */
    fun requestBackgroundLocationPermission(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:${context.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                
                Log.d(TAG, "Requesting background location permission via settings")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request background location permission", e)
        }
    }
    
    /**
     * Request exact alarm permission (Android 12+)
     */
    fun requestExactAlarmPermission(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:${context.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                
                Log.d(TAG, "Requesting exact alarm permission")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request exact alarm permission", e)
        }
    }
    
    /**
     * Request notification permission (Android 13+)
     */
    fun requestNotificationPermission(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:${context.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                
                Log.d(TAG, "Requesting notification permission via settings")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request notification permission", e)
        }
    }
    
    /**
     * Open location settings
     */
    fun openLocationSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            
            Log.d(TAG, "Opening location settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open location settings", e)
        }
    }
    
    /**
     * Open app settings
     */
    fun openAppSettings(context: Context) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:${context.packageName}")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            
            Log.d(TAG, "Opening app settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings", e)
        }
    }
    
    /**
     * Get missing permissions list
     */
    fun getMissingPermissions(context: Context): List<String> {
        val missingPermissions = mutableListOf<String>()
        
        if (!hasLocationPermissions(context)) {
            missingPermissions.add("Location permissions")
        }
        
        if (!hasBackgroundLocationPermission(context)) {
            missingPermissions.add("Background location permission")
        }
        
        if (!hasNotificationPermission(context)) {
            missingPermissions.add("Notification permission")
        }
        
        if (!hasExactAlarmPermission(context)) {
            missingPermissions.add("Exact alarm permission")
        }
        
        return missingPermissions
    }
    
    /**
     * Get permission setup instructions
     */
    fun getPermissionInstructions(context: Context): List<String> {
        val instructions = mutableListOf<String>()
        
        if (!hasLocationPermissions(context)) {
            instructions.add("Grant location permissions when prompted")
        }
        
        if (!hasBackgroundLocationPermission(context)) {
            instructions.add("Allow location access 'All the time' in app settings")
        }
        
        if (!hasNotificationPermission(context)) {
            instructions.add("Enable notifications for this app")
        }
        
        if (!hasExactAlarmPermission(context)) {
            instructions.add("Allow exact alarms for reliable location tracking")
        }
        
        // Add battery optimization instructions
        if (!BatteryOptimizationHelper.isBatteryOptimizationDisabled(context)) {
            instructions.add("Disable battery optimization for this app")
        }
        
        return instructions
    }
    
    /**
     * Check if location services are enabled
     */
    fun isLocationServiceEnabled(context: Context): Boolean {
        return try {
            val locationMode = Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.LOCATION_MODE
            )
            locationMode != Settings.Secure.LOCATION_MODE_OFF
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check location service status", e)
            false
        }
    }
    
    /**
     * Get comprehensive permission status
     */
    fun getPermissionStatus(context: Context): Map<String, Boolean> {
        return mapOf(
            "location" to hasLocationPermissions(context),
            "backgroundLocation" to hasBackgroundLocationPermission(context),
            "notification" to hasNotificationPermission(context),
            "exactAlarm" to hasExactAlarmPermission(context),
            "batteryOptimization" to BatteryOptimizationHelper.isBatteryOptimizationDisabled(context),
            "locationService" to isLocationServiceEnabled(context)
        )
    }
}