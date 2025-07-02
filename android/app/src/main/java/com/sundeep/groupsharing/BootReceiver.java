package com.sundeep.groupsharing;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

/**
 * Boot Receiver
 * 
 * This receiver automatically restarts location services when the device boots up.
 * This ensures that location sharing continues even after device restarts.
 */
public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";
    private static final String PREFS_NAME = "location_service_prefs";
    private static final String KEY_WAS_TRACKING = "was_tracking";
    private static final String KEY_USER_ID = "user_id";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.d(TAG, "BootReceiver received action: " + action);
        
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) ||
            "android.intent.action.QUICKBOOT_POWERON".equals(action) ||
            Intent.ACTION_MY_PACKAGE_REPLACED.equals(action) ||
            Intent.ACTION_PACKAGE_REPLACED.equals(action) ||
            Intent.ACTION_REBOOT.equals(action) ||
            "com.htc.intent.action.QUICKBOOT_POWERON".equals(action)) {
            
            Log.d(TAG, "Device booted, checking if location service should be restarted");
            
            // Check if location service was running before reboot
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            boolean wasTracking = prefs.getBoolean(KEY_WAS_TRACKING, false);
            String userId = prefs.getString(KEY_USER_ID, null);
            
            if (wasTracking && userId != null && !userId.isEmpty()) {
                Log.d(TAG, "Restarting location service for user: " + userId.substring(0, Math.min(8, userId.length())));
                
                try {
                    Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
                    serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                    
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent);
                    } else {
                        context.startService(serviceIntent);
                    }
                    
                    Log.d(TAG, "Location service restarted successfully");
                } catch (Exception e) {
                    Log.e(TAG, "Error restarting location service: " + e.getMessage());
                }
            } else {
                Log.d(TAG, "Location service was not running before reboot, not restarting");
            }
        }
    }
    
    /**
     * Save the current tracking state to be restored after reboot
     */
    public static void saveTrackingState(Context context, boolean isTracking, String userId) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putBoolean(KEY_WAS_TRACKING, isTracking);
        editor.putString(KEY_USER_ID, userId);
        editor.apply();
        
        Log.d(TAG, "Tracking state saved: " + isTracking + " for user: " + 
              (userId != null ? userId.substring(0, Math.min(8, userId.length())) : "null"));
    }
}