package com.sundeep.groupsharing;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;

/**
 * Battery Optimization Helper
 * 
 * This class provides methods to manage battery optimization settings
 * to ensure background location services work reliably.
 */
public class BatteryOptimizationHelper {
    private static final String TAG = "BatteryOptimizationHelper";
    public static final BatteryOptimizationHelper INSTANCE = new BatteryOptimizationHelper();
    
    private BatteryOptimizationHelper() {}
    
    public boolean isBatteryOptimizationDisabled(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
            }
        }
        return true; // Assume disabled for older versions
    }
    
    public void requestBatteryOptimizationExemption(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isBatteryOptimizationDisabled(activity)) {
                Log.d(TAG, "Requesting battery optimization exemption");
                try {
                    Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                    intent.setData(Uri.parse("package:" + activity.getPackageName()));
                    activity.startActivity(intent);
                } catch (Exception e) {
                    Log.e(TAG, "Error requesting battery optimization exemption: " + e.getMessage());
                    // Fallback to general battery optimization settings
                    try {
                        Intent fallbackIntent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                        activity.startActivity(fallbackIntent);
                    } catch (Exception fallbackException) {
                        Log.e(TAG, "Error opening battery optimization settings: " + fallbackException.getMessage());
                    }
                }
            }
        }
    }
    
    public void requestAutoStartPermission(Activity activity) {
        Log.d(TAG, "Requesting auto-start permission");
        
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        Intent intent = null;
        
        try {
            switch (manufacturer) {
                case "xiaomi":
                    intent = new Intent();
                    intent.setClassName("com.miui.securitycenter", 
                        "com.miui.permcenter.autostart.AutoStartManagementActivity");
                    break;
                case "oppo":
                    intent = new Intent();
                    intent.setClassName("com.coloros.safecenter", 
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity");
                    break;
                case "vivo":
                    intent = new Intent();
                    intent.setClassName("com.vivo.permissionmanager", 
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity");
                    break;
                case "huawei":
                case "honor":
                    intent = new Intent();
                    intent.setClassName("com.huawei.systemmanager", 
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity");
                    break;
                default:
                    // Generic approach - open app settings
                    intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    intent.setData(Uri.parse("package:" + activity.getPackageName()));
                    break;
            }
            
            if (intent != null) {
                activity.startActivity(intent);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening auto-start settings: " + e.getMessage());
            // Fallback to app settings
            try {
                Intent fallbackIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                fallbackIntent.setData(Uri.parse("package:" + activity.getPackageName()));
                activity.startActivity(fallbackIntent);
            } catch (Exception fallbackException) {
                Log.e(TAG, "Error opening app settings: " + fallbackException.getMessage());
            }
        }
    }
    
    public void requestBackgroundAppPermission(Activity activity) {
        Log.d(TAG, "Requesting background app permission");
        
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        Intent intent = null;
        
        try {
            switch (manufacturer) {
                case "xiaomi":
                    intent = new Intent();
                    intent.setClassName("com.miui.securitycenter", 
                        "com.miui.permcenter.permissions.PermissionsEditorActivity");
                    break;
                case "oppo":
                    intent = new Intent();
                    intent.setClassName("com.coloros.safecenter", 
                        "com.coloros.safecenter.permission.PermissionManagerActivity");
                    break;
                case "vivo":
                    intent = new Intent();
                    intent.setClassName("com.vivo.permissionmanager", 
                        "com.vivo.permissionmanager.activity.PurviewTabActivity");
                    break;
                case "huawei":
                case "honor":
                    intent = new Intent();
                    intent.setClassName("com.huawei.systemmanager", 
                        "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity");
                    break;
                default:
                    // Generic approach - open app settings
                    intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    intent.setData(Uri.parse("package:" + activity.getPackageName()));
                    break;
            }
            
            if (intent != null) {
                activity.startActivity(intent);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening background app settings: " + e.getMessage());
            // Fallback to app settings
            try {
                Intent fallbackIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                fallbackIntent.setData(Uri.parse("package:" + activity.getPackageName()));
                activity.startActivity(fallbackIntent);
            } catch (Exception fallbackException) {
                Log.e(TAG, "Error opening app settings: " + fallbackException.getMessage());
            }
        }
    }
    
    public void openBackgroundActivitySettings(Activity activity) {
        Log.d(TAG, "Opening background activity settings");
        
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        Intent intent = null;
        
        try {
            switch (manufacturer) {
                case "xiaomi":
                    // Try MIUI background activity settings
                    intent = new Intent();
                    intent.setClassName("com.miui.securitycenter", 
                        "com.miui.permcenter.permissions.PermissionsEditorActivity");
                    intent.putExtra("extra_pkgname", activity.getPackageName());
                    break;
                case "oneplus":
                    // OnePlus background activity settings
                    intent = new Intent();
                    intent.setClassName("com.oneplus.security", 
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity");
                    break;
                case "oppo":
                case "realme":
                    // ColorOS background activity settings
                    intent = new Intent();
                    intent.setClassName("com.coloros.safecenter", 
                        "com.coloros.safecenter.permission.PermissionManagerActivity");
                    break;
                case "vivo":
                    // Vivo background activity settings
                    intent = new Intent();
                    intent.setClassName("com.vivo.permissionmanager", 
                        "com.vivo.permissionmanager.activity.PurviewTabActivity");
                    break;
                case "huawei":
                case "honor":
                    // Huawei/Honor background activity settings
                    intent = new Intent();
                    intent.setClassName("com.huawei.systemmanager", 
                        "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity");
                    break;
                case "samsung":
                    // Samsung background activity settings
                    intent = new Intent();
                    intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                    intent.setData(Uri.parse("package:" + activity.getPackageName()));
                    break;
                default:
                    // Generic approach - try to open app-specific battery settings
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        intent = new Intent();
                        intent.setAction(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                    } else {
                        intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                        intent.setData(Uri.parse("package:" + activity.getPackageName()));
                    }
                    break;
            }
            
            if (intent != null) {
                activity.startActivity(intent);
                Log.d(TAG, "Opened background activity settings for " + manufacturer);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening background activity settings: " + e.getMessage());
            // Fallback to app settings
            try {
                Intent fallbackIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                fallbackIntent.setData(Uri.parse("package:" + activity.getPackageName()));
                activity.startActivity(fallbackIntent);
                Log.d(TAG, "Opened fallback app settings");
            } catch (Exception fallbackException) {
                Log.e(TAG, "Error opening fallback settings: " + fallbackException.getMessage());
            }
        }
    }
}