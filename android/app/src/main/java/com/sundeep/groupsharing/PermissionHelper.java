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
            case "openOnePlusAutoStart":
                openOnePlusAutoStartSettings(context);
                result.success(true);
                break;
            case "openOnePlusBackgroundSettings":
                openOnePlusBackgroundSettings(context);
                result.success(true);
                break;
            case "openOnePlusAppLockSettings":
                openOnePlusAppLockSettings(context);
                result.success(true);
                break;
            case "openOnePlusGamingMode":
                openOnePlusGamingModeSettings(context);
                result.success(true);
                break;
            case "checkOnePlusOptimizations":
                result.success(checkOnePlusOptimizations(context));
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
    
    /**
     * Check if device is OnePlus
     */
    public static boolean isOnePlusDevice() {
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        String brand = Build.BRAND.toLowerCase();
        return manufacturer.contains("oneplus") || 
               brand.contains("oneplus") ||
               manufacturer.contains("oppo"); // OnePlus is owned by Oppo
    }
    
    /**
     * Open OnePlus-specific auto-start settings
     */
    public static void openOnePlusAutoStartSettings(Context context) {
        try {
            Intent intent = null;
            
            // Try OnePlus specific auto-start settings
            try {
                intent = new Intent();
                intent.setComponent(new android.content.ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                ));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened OnePlus auto-start settings");
                return;
            } catch (Exception e) {
                Log.d(TAG, "OnePlus auto-start not available, trying alternatives");
            }
            
            // Try Oppo/ColorOS auto-start (OnePlus uses ColorOS)
            try {
                intent = new Intent();
                intent.setComponent(new android.content.ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                ));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened ColorOS auto-start settings");
                return;
            } catch (Exception e) {
                Log.d(TAG, "ColorOS auto-start not available");
            }
            
            // Fallback to generic auto-start
            openAutoStartSettings(context);
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening OnePlus auto-start settings", e);
            openAppSettings(context);
        }
    }
    
    /**
     * Open OnePlus-specific background settings
     */
    public static void openOnePlusBackgroundSettings(Context context) {
        try {
            // Try to open battery optimization settings
            Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + context.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            Log.d(TAG, "Opened OnePlus background settings");
        } catch (Exception e) {
            Log.e(TAG, "Error opening OnePlus background settings", e);
            openBatterySettings(context);
        }
    }
    
    /**
     * Open OnePlus app lock settings
     */
    public static void openOnePlusAppLockSettings(Context context) {
        try {
            Intent intent = null;
            
            // Try OnePlus app lock
            try {
                intent = new Intent();
                intent.setComponent(new android.content.ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.applock.AppLockActivity"
                ));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened OnePlus app lock settings");
                return;
            } catch (Exception e) {
                Log.d(TAG, "OnePlus app lock not available");
            }
            
            // Try ColorOS app lock
            try {
                intent = new Intent();
                intent.setComponent(new android.content.ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.applock.AppLockActivity"
                ));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened ColorOS app lock settings");
                return;
            } catch (Exception e) {
                Log.d(TAG, "ColorOS app lock not available");
            }
            
            // Fallback to app settings
            openAppSettings(context);
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening OnePlus app lock settings", e);
            openAppSettings(context);
        }
    }
    
    /**
     * Open OnePlus gaming mode settings
     */
    public static void openOnePlusGamingModeSettings(Context context) {
        try {
            Intent intent = null;
            
            // Try OnePlus Game Space
            try {
                intent = new Intent();
                intent.setComponent(new android.content.ComponentName(
                    "com.oneplus.gamespace",
                    "com.oneplus.gamespace.MainActivity"
                ));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                Log.d(TAG, "Opened OnePlus Game Space");
                return;
            } catch (Exception e) {
                Log.d(TAG, "OnePlus Game Space not available");
            }
            
            // Try generic gaming mode
            try {
                Intent settingsIntent = new Intent(Settings.ACTION_SETTINGS);
                settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(settingsIntent);
                Log.d(TAG, "Opened general settings for gaming mode");
            } catch (Exception e) {
                Log.d(TAG, "Could not open settings");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening OnePlus gaming mode settings", e);
        }
    }
    
    /**
     * Check OnePlus-specific optimizations
     */
    public static boolean checkOnePlusOptimizations(Context context) {
        try {
            // Check if battery optimization is disabled
            boolean batteryOptDisabled = isBatteryOptimizationDisabled(context);
            
            // For OnePlus, we mainly rely on battery optimization status
            // Other settings can't be checked programmatically
            
            Log.d(TAG, "OnePlus optimization check - Battery optimization disabled: " + batteryOptDisabled);
            return batteryOptDisabled;
            
        } catch (Exception e) {
            Log.e(TAG, "Error checking OnePlus optimizations", e);
            return false;
        }
    }
    
    /**
     * Get OnePlus-specific setup instructions
     */
    public static String getOnePlusSetupInstructions() {
        return "OnePlus Setup Required:\n\n" +
               "1. Battery Optimization: Settings > Battery > Battery optimization > GroupSharing > Don't optimize\n" +
               "2. Auto-start: Settings > Apps > Auto-start management > GroupSharing > Enable\n" +
               "3. Background Activity: Settings > Apps > App management > GroupSharing > Battery > Unrestricted\n" +
               "4. Location Permission: Settings > Privacy > Permission manager > Location > GroupSharing > Allow all the time\n" +
               "5. Sleep Standby: Settings > Battery > More battery settings > Sleep standby optimization > Disable\n\n" +
               "These settings are CRITICAL for OnePlus devices to allow background location sharing.";
    }
}