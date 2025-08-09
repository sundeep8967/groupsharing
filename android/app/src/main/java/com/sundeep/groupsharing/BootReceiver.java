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
                    // Add delay to ensure system is fully booted
                    android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
                    handler.postDelayed(() -> {
                        try {
                            Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
                            serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                            
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                                context.startForegroundService(serviceIntent);
                            } else {
                                context.startService(serviceIntent);
                            }
                            
                            Log.d(TAG, "Location service restarted successfully after boot");
                            
                            // Start service watchdog to monitor service health
                            startServiceWatchdog(context, userId);
                            
                        } catch (Exception e) {
                            Log.e(TAG, "Error restarting location service after delay: " + e.getMessage());
                        }
                    }, 5000); // 5 second delay
                    
                } catch (Exception e) {
                    Log.e(TAG, "Error setting up location service restart: " + e.getMessage());
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
    
    /**
     * Start service watchdog to monitor and restart service if needed
     */
    private static void startServiceWatchdog(Context context, String userId) {
        Log.d(TAG, "Starting service watchdog");
        
        android.os.Handler watchdogHandler = new android.os.Handler(android.os.Looper.getMainLooper());
        
        Runnable watchdogRunnable = new Runnable() {
            @Override
            public void run() {
                try {
                    // Check if service is still running
                    if (!isServiceRunning(context, BackgroundLocationService.class)) {
                        Log.w(TAG, "Service watchdog detected service is not running - restarting");
                        
                        Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
                        serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                        
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent);
                        } else {
                            context.startService(serviceIntent);
                        }
                        
                        Log.d(TAG, "Service restarted by watchdog");
                    } else {
                        Log.d(TAG, "Service watchdog: Service is running normally");
                    }
                    
                    // Schedule next check in 2 minutes
                    watchdogHandler.postDelayed(this, 120000);
                    
                } catch (Exception e) {
                    Log.e(TAG, "Error in service watchdog: " + e.getMessage());
                    // Continue monitoring despite errors
                    watchdogHandler.postDelayed(this, 120000);
                }
            }
        };
        
        // Start watchdog with initial delay of 1 minute
        watchdogHandler.postDelayed(watchdogRunnable, 60000);
    }
    
    /**
     * Check if a specific service is running
     */
    private static boolean isServiceRunning(Context context, Class<?> serviceClass) {
        android.app.ActivityManager manager = (android.app.ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        if (manager != null) {
            for (android.app.ActivityManager.RunningServiceInfo service : manager.getRunningServices(Integer.MAX_VALUE)) {
                if (serviceClass.getName().equals(service.service.getClassName())) {
                    return true;
                }
            }
        }
        return false;
    }
}