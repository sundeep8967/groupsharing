package com.sundeep.groupsharing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.content.SharedPreferences

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "location_sharing_prefs"
        private const val KEY_LOCATION_SHARING_ENABLED = "location_sharing_enabled"
        private const val KEY_USER_ID = "user_id"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Boot receiver triggered: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                restoreLocationSharing(context)
            }
        }
    }
    
    private fun restoreLocationSharing(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isLocationSharingEnabled = prefs.getBoolean(KEY_LOCATION_SHARING_ENABLED, false)
            val userId = prefs.getString(KEY_USER_ID, null)
            
            Log.d(TAG, "Checking location sharing state: enabled=$isLocationSharingEnabled, userId=$userId")
            
            if (isLocationSharingEnabled && !userId.isNullOrEmpty()) {
                Log.d(TAG, "Restarting location services for user: ${userId.substring(0, 8)}")
                
                // Start both services for maximum reliability on OnePlus devices
                BackgroundLocationService.startService(context, userId)
                PersistentLocationService.startPersistentService(context, userId)
            } else {
                Log.d(TAG, "Location sharing was not enabled, not starting service")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring location sharing", e)
        }
    }
}