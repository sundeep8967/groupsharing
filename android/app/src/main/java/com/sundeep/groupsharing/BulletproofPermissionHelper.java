package com.sundeep.groupsharing;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

/**
 * Bulletproof Permission Helper
 * 
 * This class provides comprehensive permission management for location services.
 */
public class BulletproofPermissionHelper {
    private static final String TAG = "BulletproofPermissionHelper";
    public static final BulletproofPermissionHelper INSTANCE = new BulletproofPermissionHelper();
    
    private BulletproofPermissionHelper() {}
    
    public boolean hasLocationPermissions(Context context) {
        boolean fineLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED;
        boolean coarseLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED;
        
        return fineLocation && coarseLocation;
    }
    
    public boolean hasBackgroundLocationPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
                == PackageManager.PERMISSION_GRANTED;
        }
        return true; // Not required for Android < Q
    }
    
    public void requestBackgroundLocationPermission(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (!hasBackgroundLocationPermission(activity)) {
                Log.d(TAG, "Requesting background location permission");
                ActivityCompat.requestPermissions(activity, 
                    new String[]{Manifest.permission.ACCESS_BACKGROUND_LOCATION}, 
                    1002);
            }
        }
    }
    
    public boolean hasExactAlarmPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Check if exact alarm permission is granted
            // This is a simplified check
            return true; // Placeholder implementation
        }
        return true; // Not required for Android < S
    }
    
    public void requestExactAlarmPermission(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Log.d(TAG, "Requesting exact alarm permission");
            try {
                Intent intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
                intent.setData(Uri.parse("package:" + activity.getPackageName()));
                activity.startActivity(intent);
            } catch (Exception e) {
                Log.e(TAG, "Error requesting exact alarm permission: " + e.getMessage());
            }
        }
    }
}