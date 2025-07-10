package com.sundeep.groupsharing;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import android.Manifest;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.provider.Settings;
import android.app.Activity;

import com.google.firebase.FirebaseApp;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Universal Background Location Service - AUTOMATIC UPDATES ENHANCED
 * 
 * This service provides persistent background location tracking for ALL authenticated users.
 * It creates a foreground notification with "Update Now" button that works even when the app is closed.
 * 
 * CRITICAL ENHANCEMENT: Now has AUTOMATIC location updates every 20 seconds + Manual updates
 * 
 * Key Features:
 * - Works for ANY user ID (not just test users)
 * - AUTOMATIC location updates every 20 seconds
 * - Manual "Update Now" button functionality
 * - Real-time Firebase sync
 * - Survives app kills
 * - Works when screen is off (Wake Lock + Automatic Updates)
 */
public class BackgroundLocationService extends Service implements LocationListener {
    private static final String TAG = "BackgroundLocationService";
    private static final String CHANNEL_ID = "location_sharing_channel";
    private static final int NOTIFICATION_ID = 1001;
    
    public static final String EXTRA_USER_ID = "userId";
    public static final String ACTION_UPDATE_NOW = "com.sundeep.groupsharing.UPDATE_NOW";
    public static final String ACTION_STOP_SERVICE = "com.sundeep.groupsharing.STOP_SERVICE";
    
    private LocationManager locationManager;
    private String currentUserId;
    private FirebaseDatabase firebaseDatabase;
    private DatabaseReference locationsRef;
    private DatabaseReference usersRef;
    private NotificationManager notificationManager;
    private PowerManager.WakeLock wakeLock;
    private Handler locationHandler;
    private Runnable locationRunnable;
    
    // Location update configuration - ULTRA AGGRESSIVE for automatic updates
    private static final long MIN_TIME_BETWEEN_UPDATES = 10000; // 10 seconds (very frequent)
    private static final float MIN_DISTANCE_CHANGE = 0; // 0 meters (any movement)
    private static final long AUTOMATIC_UPDATE_INTERVAL = 20000; // 20 seconds automatic updates
    private static final long FALLBACK_UPDATE_INTERVAL = 45000; // 45 seconds fallback
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BackgroundLocationService created (AUTOMATIC UPDATES ENHANCED)");
        
        // Initialize Firebase in this process
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this);
                Log.d(TAG, "Firebase initialized in background service process");
            }
            
            firebaseDatabase = FirebaseDatabase.getInstance();
            locationsRef = firebaseDatabase.getReference("locations");
            usersRef = firebaseDatabase.getReference("users");
            Log.d(TAG, "Firebase database references created");
        } catch (Exception e) {
            Log.e(TAG, "Error initializing Firebase: " + e.getMessage());
            // Continue without Firebase - service can still run for notifications
        }
        
        // Initialize notification manager
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        createNotificationChannel();
        
        // Initialize location manager
        locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        
        // Initialize wake lock to keep service running when screen is off
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (powerManager != null) {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GroupSharing:BackgroundLocationWakeLock"
            );
            Log.d(TAG, "Wake lock initialized for automatic location updates");
        }
        
        // Initialize handler for AUTOMATIC location updates (works always)
        locationHandler = new Handler(Looper.getMainLooper());
        locationRunnable = new Runnable() {
            @Override
            public void run() {
                // AUTOMATIC location update - works screen on/off
                forceAutomaticLocationUpdate();
                // Schedule next automatic update
                locationHandler.postDelayed(this, AUTOMATIC_UPDATE_INTERVAL);
            }
        };
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BackgroundLocationService onStartCommand (AUTOMATIC UPDATES MODE)");
        
        // Handle service restart scenarios
        if (intent == null) {
            Log.d(TAG, "Service restarted by system (intent is null) - attempting recovery");
            // Try to recover from saved state
            if (attemptServiceRecovery()) {
                return START_STICKY; // Continue with recovered state
            } else {
                Log.w(TAG, "Could not recover service state, stopping service");
                stopSelf();
                return START_NOT_STICKY;
            }
        }
        
        if (intent != null) {
            String action = intent.getAction();
            
            if (ACTION_UPDATE_NOW.equals(action)) {
                Log.d(TAG, "UPDATE_NOW action received (MANUAL update)");
                handleUpdateNowAction();
                return START_STICKY;
            } else if (ACTION_STOP_SERVICE.equals(action)) {
                Log.d(TAG, "STOP_SERVICE action received");
                stopLocationUpdates();
                stopSelf();
                return START_NOT_STICKY;
            }
            
            // Get user ID from intent
            currentUserId = intent.getStringExtra(EXTRA_USER_ID);
            if (currentUserId == null || currentUserId.isEmpty()) {
                Log.e(TAG, "No user ID provided, stopping service");
                stopSelf();
                return START_NOT_STICKY;
            }
            
            Log.d(TAG, "Starting background location service for user: " + currentUserId.substring(0, Math.min(8, currentUserId.length())));
            
            // Start foreground service with notification
            startForeground(NOTIFICATION_ID, createNotification());
            
            // Acquire wake lock to keep service running when screen is off
            if (wakeLock != null && !wakeLock.isHeld()) {
                wakeLock.acquire();
                Log.d(TAG, "Wake lock acquired - automatic updates will work when screen is off");
            }
            
            // Start location updates (system-based)
            startLocationUpdates();
            
            // Start AUTOMATIC location updates (timer-based)
            startAutomaticLocationUpdates();
            
            // Update user status in Firebase
            updateUserLocationSharingStatus(true);
            
            // Save tracking state for boot recovery
            BootReceiver.saveTrackingState(this, true, currentUserId);
        }
        
        return START_STICKY; // Restart if killed by system
    }
    
    @Override
    public void onDestroy() {
        Log.d(TAG, "BackgroundLocationService destroyed");
        stopLocationUpdates();
        stopAutomaticLocationUpdates();
        
        // Release wake lock
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
            Log.d(TAG, "Wake lock released");
        }
        
        // Update user status in Firebase
        if (currentUserId != null) {
            updateUserLocationSharingStatus(false);
            // Clear tracking state
            BootReceiver.saveTrackingState(this, false, currentUserId);
        }
        
        super.onDestroy();
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null; // Not a bound service
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Location Sharing",
                NotificationManager.IMPORTANCE_HIGH  // High importance to prevent killing
            );
            channel.setDescription("Persistent background location sharing service");
            channel.setShowBadge(false);
            channel.enableLights(false);
            channel.enableVibration(false);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            channel.setBypassDnd(true);  // Bypass Do Not Disturb
            channel.setSound(null, null);  // No sound for persistent notification
            
            // Android 8.0+ specific settings for persistence
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                channel.setImportance(NotificationManager.IMPORTANCE_HIGH);
            }
            
            // Android 13+ specific settings
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                channel.setAllowBubbles(false);
            }
            
            notificationManager.createNotificationChannel(channel);
        }
    }
    
    private Notification createNotification() {
        // Create intent for opening the app
        Intent openAppIntent = new Intent(this, MainActivity.class);
        openAppIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent, 
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );
        
        // Create intent for "Update Now" action
        Intent updateNowIntent = new Intent(this, BackgroundLocationService.class);
        updateNowIntent.setAction(ACTION_UPDATE_NOW);
        PendingIntent updateNowPendingIntent = PendingIntent.getService(
            this, 1, updateNowIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );
        
        // Create intent for "Stop" action
        Intent stopIntent = new Intent(this, BackgroundLocationService.class);
        stopIntent.setAction(ACTION_STOP_SERVICE);
        PendingIntent stopPendingIntent = PendingIntent.getService(
            this, 2, stopIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );
        
        // Get app icon for better notification appearance
        int iconResource = getApplicationInfo().icon;
        if (iconResource == 0) {
            iconResource = android.R.drawable.ic_menu_mylocation;
        }
        
        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Sharing your location in background")
            .setSmallIcon(iconResource)
            .setContentIntent(openAppPendingIntent)
            .addAction(android.R.drawable.ic_menu_mylocation, "Update Now", updateNowPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)  // Make notification persistent - cannot be swiped away
            .setPriority(NotificationCompat.PRIORITY_HIGH)  // High priority to prevent system killing
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setAutoCancel(false)  // Prevent auto-cancellation
            .setLocalOnly(true)  // Keep notification local to device
            .setOnlyAlertOnce(true)  // Only alert once to avoid spam
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)  // Immediate foreground service
            .build();
    }
    
    private void startLocationUpdates() {
        if (locationManager == null) {
            Log.e(TAG, "LocationManager is null");
            return;
        }
        
        // Check permissions
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "Location permission not granted");
            return;
        }
        
        try {
            // Request location updates from both GPS and Network providers
            // Use aggressive settings for system-based updates
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    MIN_TIME_BETWEEN_UPDATES,
                    MIN_DISTANCE_CHANGE,
                    this,
                    Looper.getMainLooper()
                );
                Log.d(TAG, "GPS location updates started (system-based, 10s interval)");
            }
            
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    MIN_TIME_BETWEEN_UPDATES,
                    MIN_DISTANCE_CHANGE,
                    this,
                    Looper.getMainLooper()
                );
                Log.d(TAG, "Network location updates started (system-based, 10s interval)");
            }
            
            // Also request passive location updates for better performance
            if (locationManager.isProviderEnabled(LocationManager.PASSIVE_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.PASSIVE_PROVIDER,
                    MIN_TIME_BETWEEN_UPDATES,
                    MIN_DISTANCE_CHANGE,
                    this,
                    Looper.getMainLooper()
                );
                Log.d(TAG, "Passive location updates started (system-based)");
            }
            
            // Get last known location immediately
            Location lastKnownLocation = getLastKnownLocation();
            if (lastKnownLocation != null) {
                onLocationChanged(lastKnownLocation);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error starting location updates: " + e.getMessage());
        }
    }
    
    private void stopLocationUpdates() {
        if (locationManager != null) {
            try {
                locationManager.removeUpdates(this);
                Log.d(TAG, "Location updates stopped");
            } catch (Exception e) {
                Log.e(TAG, "Error stopping location updates: " + e.getMessage());
            }
        }
    }
    
    private Location getLastKnownLocation() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            return null;
        }
        
        try {
            Location gpsLocation = null;
            Location networkLocation = null;
            
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                gpsLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER);
            }
            
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                networkLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER);
            }
            
            // Return the most recent location
            if (gpsLocation != null && networkLocation != null) {
                return gpsLocation.getTime() > networkLocation.getTime() ? gpsLocation : networkLocation;
            } else if (gpsLocation != null) {
                return gpsLocation;
            } else {
                return networkLocation;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting last known location: " + e.getMessage());
            return null;
        }
    }
    
    private void handleUpdateNowAction() {
        Log.d(TAG, "Handling MANUAL Update Now action");
        
        if (currentUserId == null) {
            Log.e(TAG, "No current user ID for update now action");
            return;
        }
        
        // For manual updates, use the internal method
        forceLocationUpdateInternal();
    }
    
    @Override
    public void onLocationChanged(Location location) {
        if (location == null || currentUserId == null) {
            return;
        }
        
        // Calculate location age
        long locationAge = System.currentTimeMillis() - location.getTime();
        String ageText = locationAge < 60000 ? (locationAge/1000) + "s old" : (locationAge/60000) + "m old";
        
        Log.d(TAG, "LOCATION UPDATE: " + location.getLatitude() + ", " + location.getLongitude() + 
              " (accuracy: " + location.getAccuracy() + "m, " + ageText + ") " +
              " for user: " + currentUserId.substring(0, Math.min(8, currentUserId.length())));
        
        // Update Firebase with new location
        updateLocationInFirebase(location);
    }
    
    private void updateLocationInFirebase(Location location) {
        if (currentUserId == null || location == null) {
            return;
        }
        
        if (locationsRef == null || usersRef == null) {
            Log.w(TAG, "Firebase not available, skipping location update");
            return;
        }
        
        try {
            long timestamp = System.currentTimeMillis();
            String timestampReadable = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                .format(new Date(timestamp));
            
            // Create location data
            Map<String, Object> locationData = new HashMap<>();
            locationData.put("lat", location.getLatitude());
            locationData.put("lng", location.getLongitude());
            locationData.put("timestamp", timestamp);
            locationData.put("timestampReadable", timestampReadable);
            locationData.put("isSharing", true);
            locationData.put("accuracy", (double) location.getAccuracy());
            locationData.put("automaticUpdates", true); // Indicate automatic updates are working
            locationData.put("updateInterval", AUTOMATIC_UPDATE_INTERVAL); // Show update interval
            
            // Update locations node
            locationsRef.child(currentUserId).setValue(locationData)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "Location updated successfully in Firebase (automatic mode) for user: " + 
                          currentUserId.substring(0, Math.min(8, currentUserId.length())));
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Failed to update location in Firebase: " + e.getMessage());
                });
            
            // Also update user's last location update timestamp
            Map<String, Object> userUpdate = new HashMap<>();
            userUpdate.put("lastLocationUpdate", timestamp);
            userUpdate.put("lastHeartbeat", timestamp);
            userUpdate.put("appUninstalled", false);
            userUpdate.put("automaticUpdates", true);
            userUpdate.put("updateInterval", AUTOMATIC_UPDATE_INTERVAL);
            
            usersRef.child(currentUserId).updateChildren(userUpdate);
            
        } catch (Exception e) {
            Log.e(TAG, "Error updating location in Firebase: " + e.getMessage());
        }
    }
    
    private void updateUserLocationSharingStatus(boolean isSharing) {
        if (currentUserId == null) {
            return;
        }
        
        if (usersRef == null || locationsRef == null) {
            Log.w(TAG, "Firebase not available, skipping status update");
            return;
        }
        
        try {
            long timestamp = System.currentTimeMillis();
            
            Map<String, Object> userUpdate = new HashMap<>();
            userUpdate.put("locationSharingEnabled", isSharing);
            userUpdate.put("lastSeen", timestamp);
            userUpdate.put("lastHeartbeat", timestamp);
            userUpdate.put("appUninstalled", false);
            userUpdate.put("automaticUpdates", isSharing);
            userUpdate.put("updateInterval", AUTOMATIC_UPDATE_INTERVAL);
            
            usersRef.child(currentUserId).updateChildren(userUpdate)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "User location sharing status updated (automatic mode): " + isSharing + 
                          " for user: " + currentUserId.substring(0, Math.min(8, currentUserId.length())));
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Failed to update user status: " + e.getMessage());
                });
            
            if (!isSharing) {
                // Clear location data when stopping
                locationsRef.child(currentUserId).removeValue();
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error updating user location sharing status: " + e.getMessage());
        }
    }
    
    @Override
    public void onProviderEnabled(String provider) {
        Log.d(TAG, "Location provider enabled: " + provider);
    }
    
    @Override
    public void onProviderDisabled(String provider) {
        Log.d(TAG, "Location provider disabled: " + provider);
    }
    
    @Override
    public void onStatusChanged(String provider, int status, android.os.Bundle extras) {
        Log.d(TAG, "Location provider status changed: " + provider + " status: " + status);
    }
    
    private void startAutomaticLocationUpdates() {
        if (locationHandler != null && locationRunnable != null) {
            // Start AUTOMATIC updates immediately
            locationHandler.post(locationRunnable);
            Log.d(TAG, "AUTOMATIC location updates started - every 20 seconds");
        }
    }
    
    private void stopAutomaticLocationUpdates() {
        if (locationHandler != null && locationRunnable != null) {
            locationHandler.removeCallbacks(locationRunnable);
            Log.d(TAG, "AUTOMATIC location updates stopped");
        }
    }
    
    private void forceAutomaticLocationUpdate() {
        if (currentUserId == null) {
            return;
        }
        
        Log.d(TAG, "AUTOMATIC location update triggered (every 20 seconds)");
        
        // Get current location immediately
        Location currentLocation = getLastKnownLocation();
        if (currentLocation != null) {
            // Check if location is recent enough (within last 2 minutes)
            long locationAge = System.currentTimeMillis() - currentLocation.getTime();
            if (locationAge < 120000) { // 2 minutes
                onLocationChanged(currentLocation);
                Log.d(TAG, "AUTOMATIC update: Using recent location (age: " + (locationAge/1000) + "s)");
                return;
            }
        }
        
        // Location is too old or not available, request fresh location
        Log.d(TAG, "AUTOMATIC update: Requesting fresh location");
        
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED) {
            try {
                // Try multiple providers for better success rate
                boolean requestSent = false;
                
                // First try GPS for accuracy
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    locationManager.requestSingleUpdate(
                        LocationManager.GPS_PROVIDER,
                        this,
                        Looper.getMainLooper()
                    );
                    requestSent = true;
                    Log.d(TAG, "AUTOMATIC update: GPS request sent");
                }
                
                // Also try Network for speed
                if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    locationManager.requestSingleUpdate(
                        LocationManager.NETWORK_PROVIDER,
                        this,
                        Looper.getMainLooper()
                    );
                    requestSent = true;
                    Log.d(TAG, "AUTOMATIC update: Network request sent");
                }
                
                if (!requestSent) {
                    Log.w(TAG, "AUTOMATIC update: No location providers available");
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error in automatic location update: " + e.getMessage());
            }
        }
    }
    
    private void forceLocationUpdateInternal() {
        if (currentUserId == null) {
            return;
        }
        
        Log.d(TAG, "MANUAL location update (Update Now button)");
        
        // For manual updates, always try to get fresh location
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED) {
            try {
                // Request fresh location from all available providers
                if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    locationManager.requestSingleUpdate(
                        LocationManager.GPS_PROVIDER,
                        this,
                        Looper.getMainLooper()
                    );
                    Log.d(TAG, "MANUAL update: GPS request sent");
                }
                
                if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    locationManager.requestSingleUpdate(
                        LocationManager.NETWORK_PROVIDER,
                        this,
                        Looper.getMainLooper()
                    );
                    Log.d(TAG, "MANUAL update: Network request sent");
                }
                
                // Also use last known location as immediate fallback
                Location lastKnown = getLastKnownLocation();
                if (lastKnown != null) {
                    onLocationChanged(lastKnown);
                    Log.d(TAG, "MANUAL update: Using last known location as immediate response");
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error in manual location update: " + e.getMessage());
            }
        }
    }

    /**
     * Attempt to recover service state after system restart
     * @return true if recovery successful, false otherwise
     */
    private boolean attemptServiceRecovery() {
        try {
            SharedPreferences prefs = getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE);
            boolean wasTracking = prefs.getBoolean("was_tracking", false);
            String savedUserId = prefs.getString("user_id", null);
            
            if (wasTracking && savedUserId != null && !savedUserId.isEmpty()) {
                Log.d(TAG, "Recovering service state for user: " + savedUserId.substring(0, Math.min(8, savedUserId.length())));
                
                // Restore user ID
                currentUserId = savedUserId;
                
                // Start foreground service with notification
                startForeground(NOTIFICATION_ID, createNotification());
                
                // Acquire wake lock
                if (wakeLock != null && !wakeLock.isHeld()) {
                    wakeLock.acquire();
                    Log.d(TAG, "Wake lock acquired during recovery");
                }
                
                // Start location updates
                startLocationUpdates();
                startAutomaticLocationUpdates();
                
                // Update user status
                updateUserLocationSharingStatus(true);
                
                Log.d(TAG, "Service recovery successful");
                return true;
            } else {
                Log.d(TAG, "No valid saved state found for recovery");
                return false;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error during service recovery: " + e.getMessage());
            return false;
        }
    }

    /**
     * Check if battery optimization is disabled for the app
     * @param context Application context
     * @return true if battery optimization is disabled, false otherwise
     */
    public static boolean isBatteryOptimizationDisabled(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
            }
        }
        return true; // Assume disabled for older versions
    }

    /**
     * Request to disable battery optimization for the app
     * @param activity Activity context to start the intent
     */
    public static void requestDisableBatteryOptimization(Activity activity) {
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
}