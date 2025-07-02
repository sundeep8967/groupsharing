package com.sundeep.groupsharing;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Persistent Location Service Helper
 * 
 * This class provides static methods to manage persistent location tracking.
 * It delegates to the BackgroundLocationService for actual implementation.
 */
public class PersistentLocationService {
    private static final String TAG = "PersistentLocationService";
    
    public static void startPersistentService(Context context, String userId) {
        Log.d(TAG, "Starting persistent service for user: " + userId.substring(0, Math.min(8, userId.length())));
        
        Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
        serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent);
        } else {
            context.startService(serviceIntent);
        }
    }
    
    public static void stopPersistentService(Context context) {
        Log.d(TAG, "Stopping persistent service");
        
        Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
        context.stopService(serviceIntent);
    }
    
    public static boolean isServiceRunning(Context context) {
        ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        if (manager != null) {
            for (ActivityManager.RunningServiceInfo service : manager.getRunningServices(Integer.MAX_VALUE)) {
                if (BackgroundLocationService.class.getName().equals(service.service.getClassName())) {
                    return true;
                }
            }
        }
        return false;
    }
}