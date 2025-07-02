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
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import android.Manifest;
import android.content.pm.PackageManager;

import com.google.firebase.FirebaseApp;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Universal Background Location Service
 * 
 * This service provides persistent background location tracking for ALL authenticated users.
 * It creates a foreground notification with "Update Now" button that works even when the app is closed.
 * 
 * Key Features:
 * - Works for ANY user ID (not just test users)
 * - Persistent foreground notification
 * - "Update Now" button functionality
 * - Real-time Firebase sync
 * - Survives app kills
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
    
    // Location update configuration
    private static final long MIN_TIME_BETWEEN_UPDATES = 30000; // 30 seconds
    private static final float MIN_DISTANCE_CHANGE = 10; // 10 meters
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BackgroundLocationService created");
        
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
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BackgroundLocationService onStartCommand");
        
        if (intent != null) {
            String action = intent.getAction();
            
            if (ACTION_UPDATE_NOW.equals(action)) {
                Log.d(TAG, "UPDATE_NOW action received");
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
            
            // Start location updates
            startLocationUpdates();
            
            // Update user status in Firebase
            updateUserLocationSharingStatus(true);
            
            // Save tracking state for boot recovery
            BootReceiver.saveTrackingState(this, true, currentUserId);
        }
        
        return START_STICKY; // Restart if killed
    }
    
    @Override
    public void onDestroy() {
        Log.d(TAG, "BackgroundLocationService destroyed");
        stopLocationUpdates();
        
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
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Background location sharing service");
            channel.setShowBadge(false);
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
        
        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Sharing Active")
            .setContentText("Sharing your location with family members")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(openAppPendingIntent)
            .addAction(android.R.drawable.ic_menu_mylocation, "Update Now", updateNowPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
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
            if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER,
                    MIN_TIME_BETWEEN_UPDATES,
                    MIN_DISTANCE_CHANGE,
                    this,
                    Looper.getMainLooper()
                );
                Log.d(TAG, "GPS location updates started");
            }
            
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER,
                    MIN_TIME_BETWEEN_UPDATES,
                    MIN_DISTANCE_CHANGE,
                    this,
                    Looper.getMainLooper()
                );
                Log.d(TAG, "Network location updates started");
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
        Log.d(TAG, "Handling Update Now action");
        
        if (currentUserId == null) {
            Log.e(TAG, "No current user ID for update now action");
            return;
        }
        
        // Get current location immediately
        Location currentLocation = getLastKnownLocation();
        if (currentLocation != null) {
            onLocationChanged(currentLocation);
            Log.d(TAG, "Update Now: Location updated successfully");
        } else {
            Log.w(TAG, "Update Now: No location available");
            
            // Request a fresh location update
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
                == PackageManager.PERMISSION_GRANTED) {
                try {
                    // Request single location update
                    locationManager.requestSingleUpdate(
                        LocationManager.GPS_PROVIDER,
                        this,
                        Looper.getMainLooper()
                    );
                } catch (Exception e) {
                    Log.e(TAG, "Error requesting single location update: " + e.getMessage());
                }
            }
        }
    }
    
    @Override
    public void onLocationChanged(Location location) {
        if (location == null || currentUserId == null) {
            return;
        }
        
        Log.d(TAG, "Location changed: " + location.getLatitude() + ", " + location.getLongitude() + 
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
            
            // Update locations node
            locationsRef.child(currentUserId).setValue(locationData)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "Location updated successfully in Firebase for user: " + 
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
            
            usersRef.child(currentUserId).updateChildren(userUpdate)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "User location sharing status updated: " + isSharing + 
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
}