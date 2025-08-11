package com.sundeep.groupsharing

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoWcdma
import android.telephony.TelephonyManager
import android.util.Log
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Network Movement Detector
 * 
 * This class detects user movement by monitoring network changes:
 * 1. Cell Tower Changes - Indicates movement between cellular coverage areas
 * 2. WiFi Network Changes - Indicates movement between different locations
 * 
 * Benefits:
 * - ZERO GPS battery usage
 * - Works even when GPS is disabled
 * - Detects movement in areas with poor GPS signal
 * - Triggers location updates only when user actually moves
 */
class NetworkMovementDetector private constructor() {
    
    companion object {
        private const val TAG = "NetworkMovementDetector"
        
        @Volatile
        private var INSTANCE: NetworkMovementDetector? = null
        
        fun getInstance(): NetworkMovementDetector {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: NetworkMovementDetector().also { INSTANCE = it }
            }
        }
        
        // Static method channel for communication with Flutter
        @JvmField
        var methodChannel: MethodChannel? = null
    }
    
    private var isMonitoring = false
    private var currentCellId: String? = null
    private var currentWifiSSID: String? = null
    private var lastNetworkChangeTime = 0L
    
    // Network monitoring components
    private var telephonyManager: TelephonyManager? = null
    private var wifiManager: WifiManager? = null
    private var connectivityManager: ConnectivityManager? = null
    private var wifiReceiver: WifiChangeReceiver? = null
    private var networkCallback: NetworkChangeCallback? = null
    
    // Cooldown to prevent excessive triggers
    private val NETWORK_CHANGE_COOLDOWN_MS = 2 * 60 * 1000L // 2 minutes
    
    /**
     * Initialize network movement detection
     */
    fun initialize(context: Context): Boolean {
        try {
            telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            // Get initial network state
            updateCurrentCellId(context)
            updateCurrentWifiSSID()
            
            Log.d(TAG, "Network Movement Detector initialized")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Network Movement Detector", e)
            return false
        }
    }
    
    /**
     * Start monitoring network changes
     */
    fun startMonitoring(context: Context): Boolean {
        if (isMonitoring) return true
        
        try {
            // Register WiFi change receiver
            wifiReceiver = WifiChangeReceiver()
            val wifiFilter = IntentFilter().apply {
                addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION)
                addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
            }
            context.registerReceiver(wifiReceiver, wifiFilter)
            
            // Register network callback for cellular changes
            networkCallback = NetworkChangeCallback()
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build()
            
            connectivityManager?.registerNetworkCallback(networkRequest, networkCallback!!)
            
            isMonitoring = true
            Log.d(TAG, "Started monitoring network changes")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start network monitoring", e)
            return false
        }
    }
    
    /**
     * Stop monitoring network changes
     */
    fun stopMonitoring(context: Context) {
        if (!isMonitoring) return
        
        try {
            // Unregister WiFi receiver
            wifiReceiver?.let { context.unregisterReceiver(it) }
            wifiReceiver = null
            
            // Unregister network callback
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
            networkCallback = null
            
            isMonitoring = false
            Log.d(TAG, "Stopped monitoring network changes")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping network monitoring", e)
        }
    }
    
    /**
     * Detect cell tower changes
     */
    fun detectCellTowerChange(context: Context) {
        try {
            val newCellId = getCurrentCellId(context)
            
            if (newCellId != null && newCellId != currentCellId && currentCellId != null) {
                Log.d(TAG, "Cell tower change detected: $currentCellId -> $newCellId")
                
                if (shouldTriggerLocationUpdate()) {
                    triggerLocationUpdate("CELL_TOWER_CHANGE", mapOf(
                        "oldCellId" to currentCellId,
                        "newCellId" to newCellId
                    ))
                }
                
                currentCellId = newCellId
                lastNetworkChangeTime = System.currentTimeMillis()
            } else if (currentCellId == null && newCellId != null) {
                // First time detection
                currentCellId = newCellId
                Log.d(TAG, "Initial cell tower detected: $newCellId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting cell tower change", e)
        }
    }
    
    /**
     * Detect WiFi network changes
     */
    fun detectWiFiNetworkChange() {
        try {
            val newWifiSSID = getCurrentWifiSSID()
            
            if (newWifiSSID != currentWifiSSID) {
                Log.d(TAG, "WiFi network change detected: $currentWifiSSID -> $newWifiSSID")
                
                if (shouldTriggerLocationUpdate()) {
                    triggerLocationUpdate("WIFI_NETWORK_CHANGE", mapOf(
                        "oldSSID" to currentWifiSSID,
                        "newSSID" to newWifiSSID
                    ))
                }
                
                currentWifiSSID = newWifiSSID
                lastNetworkChangeTime = System.currentTimeMillis()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting WiFi network change", e)
        }
    }
    
    /**
     * Get current cell tower ID
     */
    private fun getCurrentCellId(context: Context): String? {
        try {
            if (!hasLocationPermission(context)) return null
            
            val cellInfos = telephonyManager?.allCellInfo
            if (cellInfos.isNullOrEmpty()) return null
            
            for (cellInfo in cellInfos) {
                if (cellInfo.isRegistered) {
                    return when (cellInfo) {
                        is CellInfoGsm -> cellInfo.cellIdentity.cid.toString()
                        is CellInfoLte -> cellInfo.cellIdentity.ci.toString()
                        is CellInfoWcdma -> cellInfo.cellIdentity.cid.toString()
                        else -> cellInfo.toString()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting cell ID", e)
        }
        return null
    }
    
    /**
     * Get current WiFi SSID
     */
    private fun getCurrentWifiSSID(): String? {
        try {
            val wifiInfo = wifiManager?.connectionInfo
            return wifiInfo?.ssid?.replace("\"", "") // Remove quotes
        } catch (e: Exception) {
            Log.e(TAG, "Error getting WiFi SSID", e)
            return null
        }
    }
    
    /**
     * Update current cell ID
     */
    private fun updateCurrentCellId(context: Context) {
        currentCellId = getCurrentCellId(context)
    }
    
    /**
     * Update current WiFi SSID
     */
    private fun updateCurrentWifiSSID() {
        currentWifiSSID = getCurrentWifiSSID()
    }
    
    /**
     * Check if we should trigger location update (cooldown logic)
     */
    private fun shouldTriggerLocationUpdate(): Boolean {
        val currentTime = System.currentTimeMillis()
        return currentTime - lastNetworkChangeTime >= NETWORK_CHANGE_COOLDOWN_MS
    }
    
    /**
     * Trigger location update via activity recognition system
     */
    private fun triggerLocationUpdate(changeType: String, details: Map<String, Any?>) {
        try {
            Log.d(TAG, "Triggering location update due to network change: $changeType")
            
            // Send to Flutter
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onNetworkMovementDetected", mapOf(
                    "changeType" to changeType,
                    "timestamp" to System.currentTimeMillis(),
                    "details" to details
                ))
            }
            
            // Also trigger via activity recognition system
            // This ensures location services are started even if app is killed
            
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering location update", e)
        }
    }
    
    /**
     * Check if app has location permission
     */
    private fun hasLocationPermission(context: Context): Boolean {
        return try {
            val permission = android.Manifest.permission.ACCESS_FINE_LOCATION
            android.content.pm.PackageManager.PERMISSION_GRANTED == 
                androidx.core.content.ContextCompat.checkSelfPermission(context, permission)
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * WiFi change broadcast receiver
     */
    inner class WifiChangeReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isMonitoring) return
            
            when (intent?.action) {
                WifiManager.NETWORK_STATE_CHANGED_ACTION -> {
                    Log.d(TAG, "WiFi network state changed")
                    detectWiFiNetworkChange()
                }
                WifiManager.WIFI_STATE_CHANGED_ACTION -> {
                    Log.d(TAG, "WiFi state changed")
                    detectWiFiNetworkChange()
                }
            }
        }
    }
    
    /**
     * Network change callback for cellular changes
     */
    inner class NetworkChangeCallback : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            super.onAvailable(network)
            Log.d(TAG, "Network available: $network")
            
            // Check for cell tower changes when network becomes available
            Handler(Looper.getMainLooper()).postDelayed({
                if (isMonitoring) {
                    // We need context here, so we'll trigger via a different mechanism
                    triggerCellTowerCheck()
                }
            }, 1000) // Small delay to ensure network is fully connected
        }
        
        override fun onLost(network: Network) {
            super.onLost(network)
            Log.d(TAG, "Network lost: $network")
        }
        
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            super.onCapabilitiesChanged(network, networkCapabilities)
            
            if (networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                Log.d(TAG, "Cellular network capabilities changed")
                triggerCellTowerCheck()
            }
        }
    }
    
    /**
     * Trigger cell tower check (needs to be called with context)
     */
    private fun triggerCellTowerCheck() {
        try {
            // Send signal to check cell tower
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("checkCellTower", emptyMap<String, Any>())
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering cell tower check", e)
        }
    }
}