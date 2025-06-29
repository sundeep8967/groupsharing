package com.sundeep.groupsharing;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;
import androidx.annotation.RequiresApi;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PermissionHelper {
    
    private static final String TAG = "PermissionHelper";
    
    public static void handleMethodCall(Context context, MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "isBatteryOptimizationDisabled":
                result.success(isBatteryOptimizationDisabled(context));
                break;
            case "requestDisableBatteryOptimization":
                requestDisableBatteryOptimization(context);
                result.success(true);
                break;
            case "openAutoStartSettings":
                openAutoStartSettings(context);
                result.success(true);
                break;
            case "openAppSettings":
                openAppSettings(context);
                result.success(true);
                break;
            default:
                result.notImplemented();
                break;
        }
    }
    
    /**
     * Check if battery optimization is disabled for this app
     */
    public static boolean isBatteryOptimizationDisabled(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
        } else {
            return true; // Battery optimization doesn't exist on older versions
        }
    }
    
    /**
     * Request to disable battery optimization
     */
    @RequiresApi(Build.VERSION_CODES.M)
    public static void requestDisableBatteryOptimization(Context context) {
        try {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (!powerManager.isIgnoringBatteryOptimizations(context.getPackageName())) {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + context.getPackageName()));
                
                if (context instanceof Activity) {
                    context.startActivity(intent);
                } else {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(intent);
                }
                
                Log.d(TAG, "Requested battery optimization disable");
            } else {
                Log.d(TAG, "Battery optimization already disabled");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error requesting battery optimization disable", e);
            // Fallback to battery settings
            openBatterySettings(context);
        }
    }
    
    /**
     * Open auto-start settings for different manufacturers
     */
    public static void openAutoStartSettings(Context context) {
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        
        try {
            Intent intent = null;
            
            switch (manufacturer) {
                case "xiaomi":
                    // MIUI Auto-start settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    ));
                    break;
                case "huawei":
                    // EMUI App Launch settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    ));
                    break;
                case "oppo":
                    // ColorOS Auto-start settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    ));
                    break;
                case "vivo":
                    // FunTouch OS Auto-start settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    ));
                    break;
                case "oneplus":
                    // OxygenOS Auto-start settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                    ));
                    break;
                case "realme":
                    // Realme UI Auto-start settings
                    intent = new Intent();
                    intent.setComponent(new android.content.ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    ));
                    break;
                default:
                    // Fallback to app settings
                    intent = null;
                    break;
            }
            
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened auto-start settings for " + manufacturer);
            } else {
                // Fallback to app settings
                openAppSettings(context);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening auto-start settings for " + manufacturer, e);
            // Fallback to app settings
            openAppSettings(context);
        }
    }
    
    /**
     * Open app settings
     */
    public static void openAppSettings(Context context) {
        try {
            Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            intent.setData(Uri.parse("package:" + context.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            Log.d(TAG, "Opened app settings");
        } catch (Exception e) {
            Log.e(TAG, "Error opening app settings", e);
        }
    }
    
    /**
     * Open battery settings as fallback
     */
    private static void openBatterySettings(Context context) {
        try {
            Intent intent = new Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            Log.d(TAG, "Opened battery settings");
        } catch (Exception e) {
            Log.e(TAG, "Error opening battery settings", e);
            // Final fallback to general settings
            try {
                Intent fallbackIntent = new Intent(Settings.ACTION_SETTINGS);
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(fallbackIntent);
            } catch (Exception e2) {
                Log.e(TAG, "Error opening settings", e2);
            }
        }
    }
    
    /**
     * Get manufacturer-specific instructions for auto-start
     */
    public static String getAutoStartInstructions() {
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        
        switch (manufacturer) {
            case "xiaomi":
                return "Go to Security > Autostart > Find GroupSharing > Enable";
            case "huawei":
                return "Go to Phone Manager > App Launch > Find GroupSharing > Enable 'Manage manually'";
            case "oppo":
            case "realme":
                return "Go to Settings > Battery > App Energy Saver > Find GroupSharing > Disable";
            case "vivo":
                return "Go to Settings > Battery > Background App Refresh > Find GroupSharing > Enable";
            case "oneplus":
                return "Go to Settings > Battery > Battery Optimization > Find GroupSharing > Don't optimize";
            default:
                return "Find app management settings and enable autostart for GroupSharing";
        }
    }
    
    /**
     * Check if device requires auto-start permission
     */
    public static boolean requiresAutoStartPermission() {
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        String[] manufacturers = {"xiaomi", "huawei", "oppo", "vivo", "oneplus", "realme"};
        
        for (String mfr : manufacturers) {
            if (mfr.equals(manufacturer)) {
                return true;
            }
        }
        return false;
    }
}