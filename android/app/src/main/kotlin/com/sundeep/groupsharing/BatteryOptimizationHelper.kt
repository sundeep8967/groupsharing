package com.sundeep.groupsharing

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Battery Optimization Helper for different Android manufacturers
 * 
 * This class provides device-specific battery optimization handling
 * to ensure background location services work reliably across all devices.
 */
object BatteryOptimizationHelper {
    
    private const val TAG = "BatteryOptimizationHelper"
    
    /**
     * Request battery optimization exemption for the app
     */
    fun requestBatteryOptimizationExemption(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:${context.packageName}")
                    if (context is Activity) {
                        context.startActivity(intent)
                    } else {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery optimization exemption", e)
        }
    }
    
    /**
     * Check if battery optimization is disabled for the app
     */
    fun isBatteryOptimizationDisabled(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true // Not applicable for older versions
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check battery optimization status", e)
            false
        }
    }
    
    /**
     * Request auto-start permission for different manufacturers
     */
    fun requestAutoStartPermission(context: Context) {
        val manufacturer = Build.MANUFACTURER.lowercase()
        
        try {
            when {
                manufacturer.contains("xiaomi") -> requestXiaomiAutoStart(context)
                manufacturer.contains("oppo") -> requestOppoAutoStart(context)
                manufacturer.contains("vivo") -> requestVivoAutoStart(context)
                manufacturer.contains("huawei") -> requestHuaweiAutoStart(context)
                manufacturer.contains("honor") -> requestHonorAutoStart(context)
                manufacturer.contains("oneplus") -> requestOnePlusAutoStart(context)
                manufacturer.contains("realme") -> requestRealmeAutoStart(context)
                manufacturer.contains("samsung") -> requestSamsungAutoStart(context)
                else -> {
                    Log.d(TAG, "No specific auto-start handling for manufacturer: $manufacturer")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request auto-start permission for $manufacturer", e)
        }
    }
    
    /**
     * Request background app permission for different manufacturers
     */
    fun requestBackgroundAppPermission(context: Context) {
        val manufacturer = Build.MANUFACTURER.lowercase()
        
        try {
            when {
                manufacturer.contains("xiaomi") -> requestXiaomiBackgroundApp(context)
                manufacturer.contains("oppo") -> requestOppoBackgroundApp(context)
                manufacturer.contains("vivo") -> requestVivoBackgroundApp(context)
                manufacturer.contains("huawei") -> requestHuaweiBackgroundApp(context)
                manufacturer.contains("honor") -> requestHonorBackgroundApp(context)
                manufacturer.contains("oneplus") -> requestOnePlusBackgroundApp(context)
                manufacturer.contains("realme") -> requestRealmeBackgroundApp(context)
                else -> {
                    Log.d(TAG, "No specific background app handling for manufacturer: $manufacturer")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request background app permission for $manufacturer", e)
        }
    }
    
    // Xiaomi specific methods
    private fun requestXiaomiAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings")),
            Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT)
        )
        
        startActivitySafely(context, intents, "Xiaomi auto-start")
    }
    
    private fun requestXiaomiBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings")),
            Intent().setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"))
        )
        
        startActivitySafely(context, intents, "Xiaomi background app")
    }
    
    // OPPO specific methods
    private fun requestOppoAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"))
        )
        
        startActivitySafely(context, intents, "OPPO auto-start")
    }
    
    private fun requestOppoBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"))
        )
        
        startActivitySafely(context, intents, "OPPO background app")
    }
    
    // Vivo specific methods
    private fun requestVivoAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"))
        )
        
        startActivitySafely(context, intents, "Vivo auto-start")
    }
    
    private fun requestVivoBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"))
        )
        
        startActivitySafely(context, intents, "Vivo background app")
    }
    
    // Huawei specific methods
    private fun requestHuaweiAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"))
        )
        
        startActivitySafely(context, intents, "Huawei auto-start")
    }
    
    private fun requestHuaweiBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"))
        )
        
        startActivitySafely(context, intents, "Huawei background app")
    }
    
    // Honor specific methods
    private fun requestHonorAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
        )
        
        startActivitySafely(context, intents, "Honor auto-start")
    }
    
    private fun requestHonorBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"))
        )
        
        startActivitySafely(context, intents, "Honor background app")
    }
    
    // OnePlus specific methods
    private fun requestOnePlusAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
            Intent().setComponent(ComponentName("com.oplus.battery", "com.oplus.battery.ui.BatteryOptimizeActivity"))
        )
        
        startActivitySafely(context, intents, "OnePlus auto-start")
    }
    
    private fun requestOnePlusBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
            Intent().setComponent(ComponentName("com.oplus.battery", "com.oplus.battery.ui.BatteryOptimizeActivity"))
        )
        
        startActivitySafely(context, intents, "OnePlus background app")
    }
    
    // Realme specific methods
    private fun requestRealmeAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.realme.security", "com.realme.security.permission.startup.StartupAppListActivity"))
        )
        
        startActivitySafely(context, intents, "Realme auto-start")
    }
    
    private fun requestRealmeBackgroundApp(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.realme.security", "com.realme.security.permission.startup.StartupAppListActivity"))
        )
        
        startActivitySafely(context, intents, "Realme background app")
    }
    
    // Samsung specific methods
    private fun requestSamsungAutoStart(context: Context) {
        val intents = listOf(
            Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity"))
        )
        
        startActivitySafely(context, intents, "Samsung auto-start")
    }
    
    /**
     * Safely start an activity from a list of intents
     */
    private fun startActivitySafely(context: Context, intents: List<Intent>, description: String) {
        for (intent in intents) {
            try {
                if (context.packageManager.resolveActivity(intent, 0) != null) {
                    if (context !is Activity) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Log.d(TAG, "Successfully started $description activity")
                    return
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to start $description activity with intent: $intent", e)
            }
        }
        
        Log.w(TAG, "No suitable activity found for $description")
    }
    
    /**
     * Get device-specific optimization recommendations
     */
    fun getOptimizationRecommendations(context: Context): List<String> {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val recommendations = mutableListOf<String>()
        
        // General recommendations
        recommendations.add("Disable battery optimization for this app")
        recommendations.add("Allow the app to run in background")
        
        // Manufacturer-specific recommendations
        when {
            manufacturer.contains("xiaomi") -> {
                recommendations.add("Enable Auto-start in MIUI Security app")
                recommendations.add("Set battery saver to 'No restrictions' for this app")
                recommendations.add("Lock the app in recent apps")
            }
            manufacturer.contains("oppo") -> {
                recommendations.add("Enable Auto-start in Phone Manager")
                recommendations.add("Add app to startup management whitelist")
                recommendations.add("Disable battery optimization in Battery settings")
            }
            manufacturer.contains("vivo") -> {
                recommendations.add("Enable Auto-start in iManager")
                recommendations.add("Add app to background app refresh whitelist")
                recommendations.add("Set app to high background activity")
            }
            manufacturer.contains("huawei") -> {
                recommendations.add("Enable Auto-start in Phone Manager")
                recommendations.add("Lock app in recent apps")
                recommendations.add("Disable battery optimization in Battery settings")
            }
            manufacturer.contains("oneplus") -> {
                recommendations.add("Disable battery optimization in Battery settings")
                recommendations.add("Enable background activity for the app")
                recommendations.add("Add app to never sleeping apps list")
            }
            manufacturer.contains("samsung") -> {
                recommendations.add("Add app to never sleeping apps")
                recommendations.add("Disable adaptive battery for this app")
                recommendations.add("Enable background activity")
            }
        }
        
        return recommendations
    }
}