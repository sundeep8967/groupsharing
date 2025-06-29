package com.sundeep.groupsharing;

import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.IBinder;
import android.util.Log;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Native Android Geofence Service
 * Handles location-based triggers and smart place detection
 * Provides Life360-style geofencing with high accuracy and reliability
 */
public class GeofenceService extends Service {
    
    private static final String TAG = "GeofenceService";
    
    // Geofence configuration
    private static final long GEOFENCE_EXPIRATION_TIME = Geofence.NEVER_EXPIRE;
    private static final float DEFAULT_GEOFENCE_RADIUS = 100.0f; // 100 meters
    private static final int GEOFENCE_LOITERING_DELAY = 60000; // 1 minute
    
    // State tracking
    private boolean isInitialized = false;
    private String currentUserId;
    private List<Geofence> activeGeofences = new ArrayList<>();
    
    // Google Play Services
    private GeofencingClient geofencingClient;
    private PendingIntent geofencePendingIntent;
    
    // Firebase
    private DatabaseReference database;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "GeofenceService created");
        
        // Initialize Google Play Services
        geofencingClient = LocationServices.getGeofencingClient(this);
        
        // Initialize Firebase
        database = FirebaseDatabase.getInstance().getReference();
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getStringExtra("action");
            currentUserId = intent.getStringExtra("userId");
            
            switch (action != null ? action : "") {
                case "initialize":
                    initializeGeofencing();
                    break;
                case "add_geofence":
                    addGeofence(intent);
                    break;
                case "remove_geofence":
                    removeGeofence(intent);
                    break;
                case "clear_all":
                    clearAllGeofences();
                    break;
                case "add_smart_places":
                    addSmartPlaces();
                    break;
                default:
                    Log.w(TAG, "Unknown action: " + action);
                    break;
            }
        }
        
        return START_STICKY;
    }
    
    private void initializeGeofencing() {
        if (isInitialized) return;
        
        Log.d(TAG, "Initializing geofencing for user: " + currentUserId.substring(0, 8));
        
        // Create pending intent for geofence transitions
        createGeofencePendingIntent();
        
        // Add default smart places
        addSmartPlaces();
        
        isInitialized = true;
        Log.d(TAG, "Geofencing initialized successfully");
    }
    
    private void createGeofencePendingIntent() {
        Intent intent = new Intent(this, GeofenceTransitionReceiver.class);
        intent.putExtra("userId", currentUserId);
        
        geofencePendingIntent = PendingIntent.getBroadcast(
            this, 
            0, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
    }
    
    private void addGeofence(Intent intent) {
        String geofenceId = intent.getStringExtra("geofenceId");
        double latitude = intent.getDoubleExtra("latitude", 0.0);
        double longitude = intent.getDoubleExtra("longitude", 0.0);
        float radius = intent.getFloatExtra("radius", DEFAULT_GEOFENCE_RADIUS);
        String name = intent.getStringExtra("name");
        
        if (geofenceId == null || latitude == 0.0 || longitude == 0.0) {
            Log.w(TAG, "Invalid geofence parameters");
            return;
        }
        
        Log.d(TAG, "Adding geofence: " + geofenceId + " at " + latitude + ", " + longitude);
        
        // Create geofence
        Geofence geofence = new Geofence.Builder()
            .setRequestId(geofenceId)
            .setCircularRegion(latitude, longitude, radius)
            .setExpirationDuration(GEOFENCE_EXPIRATION_TIME)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER | 
                              Geofence.GEOFENCE_TRANSITION_EXIT |
                              Geofence.GEOFENCE_TRANSITION_DWELL)
            .setLoiteringDelay(GEOFENCE_LOITERING_DELAY)
            .build();
        
        // Create geofencing request
        GeofencingRequest geofencingRequest = new GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build();
        
        // Add geofence
        try {
            geofencingClient.addGeofences(geofencingRequest, geofencePendingIntent)
                .addOnSuccessListener(aVoid -> {
                    Log.d(TAG, "Geofence added successfully: " + geofenceId);
                    activeGeofences.add(geofence);
                    
                    // Save to Firebase
                    saveGeofenceToFirebase(geofenceId, latitude, longitude, radius, name);
                })
                .addOnFailureListener(e -> {
                    Log.e(TAG, "Failed to add geofence: " + geofenceId, e);
                });
        } catch (SecurityException e) {
            Log.e(TAG, "Location permission not granted", e);
        }
    }
    
    private void removeGeofence(Intent intent) {
        String geofenceId = intent.getStringExtra("geofenceId");
        if (geofenceId == null) return;
        
        Log.d(TAG, "Removing geofence: " + geofenceId);
        
        List<String> geofenceIds = new ArrayList<>();
        geofenceIds.add(geofenceId);
        
        geofencingClient.removeGeofences(geofenceIds)
            .addOnSuccessListener(aVoid -> {
                Log.d(TAG, "Geofence removed successfully: " + geofenceId);
                
                // Remove from active list
                activeGeofences.removeIf(geofence -> geofence.getRequestId().equals(geofenceId));
                
                // Remove from Firebase
                removeGeofenceFromFirebase(geofenceId);
            })
            .addOnFailureListener(e -> {
                Log.e(TAG, "Failed to remove geofence: " + geofenceId, e);
            });
    }
    
    private void clearAllGeofences() {
        Log.d(TAG, "Clearing all geofences");
        
        geofencingClient.removeGeofences(geofencePendingIntent)
            .addOnSuccessListener(aVoid -> {
                Log.d(TAG, "All geofences cleared successfully");
                activeGeofences.clear();
            })
            .addOnFailureListener(e -> {
                Log.e(TAG, "Failed to clear geofences", e);
            });
    }
    
    private void addSmartPlaces() {
        // Add common smart places (these would typically be user-configured)
        addPredefinedPlace("home", "Home", 0.0, 0.0, 150.0f);
        addPredefinedPlace("work", "Work", 0.0, 0.0, 100.0f);
        addPredefinedPlace("school", "School", 0.0, 0.0, 100.0f);
        
        Log.d(TAG, "Smart places setup initiated");
    }
    
    private void addPredefinedPlace(String id, String name, double lat, double lng, float radius) {
        // In a real implementation, these coordinates would come from user settings
        // For now, we'll just create the structure
        
        Map<String, Object> placeData = new HashMap<>();
        placeData.put("id", id);
        placeData.put("name", name);
        placeData.put("latitude", lat);
        placeData.put("longitude", lng);
        placeData.put("radius", radius);
        placeData.put("type", "smart_place");
        placeData.put("created", System.currentTimeMillis());
        placeData.put("source", "android_native_geofence");
        
        // Save to Firebase for Flutter to read and configure
        database.child("users").child(currentUserId).child("smartPlaces").child(id).setValue(placeData);
    }
    
    private void saveGeofenceToFirebase(String id, double lat, double lng, float radius, String name) {
        Map<String, Object> geofenceData = new HashMap<>();
        geofenceData.put("id", id);
        geofenceData.put("name", name);
        geofenceData.put("latitude", lat);
        geofenceData.put("longitude", lng);
        geofenceData.put("radius", radius);
        geofenceData.put("active", true);
        geofenceData.put("created", System.currentTimeMillis());
        geofenceData.put("source", "android_native_geofence");
        
        database.child("users").child(currentUserId).child("geofences").child(id).setValue(geofenceData);
    }
    
    private void removeGeofenceFromFirebase(String id) {
        database.child("users").child(currentUserId).child("geofences").child(id).removeValue();
    }
    
    // Handle geofence transitions (called from GeofenceTransitionReceiver)
    public static void handleGeofenceTransition(Context context, String userId, String geofenceId, 
                                              int transitionType, Location location) {
        Log.d(TAG, "Geofence transition: " + geofenceId + " - " + transitionType);
        
        DatabaseReference database = FirebaseDatabase.getInstance().getReference();
        
        // Create transition event
        Map<String, Object> eventData = new HashMap<>();
        eventData.put("geofenceId", geofenceId);
        eventData.put("transitionType", transitionType);
        eventData.put("timestamp", System.currentTimeMillis());
        eventData.put("source", "android_native_geofence");
        
        if (location != null) {
            Map<String, Object> locationData = new HashMap<>();
            locationData.put("latitude", location.getLatitude());
            locationData.put("longitude", location.getLongitude());
            locationData.put("accuracy", location.getAccuracy());
            eventData.put("location", locationData);
        }
        
        // Save event to Firebase
        database.child("users").child(userId).child("geofenceEvents").push().setValue(eventData);
        
        // Update current place status
        String transitionName = getTransitionName(transitionType);
        Map<String, Object> statusUpdate = new HashMap<>();
        statusUpdate.put("currentPlace", transitionType == Geofence.GEOFENCE_TRANSITION_ENTER ? geofenceId : null);
        statusUpdate.put("lastTransition", transitionName);
        statusUpdate.put("lastTransitionTime", System.currentTimeMillis());
        
        database.child("users").child(userId).child("placeStatus").updateChildren(statusUpdate);
        
        // Show notification for place transitions
        showPlaceNotification(context, geofenceId, transitionName);
    }
    
    private static String getTransitionName(int transitionType) {
        switch (transitionType) {
            case Geofence.GEOFENCE_TRANSITION_ENTER:
                return "entered";
            case Geofence.GEOFENCE_TRANSITION_EXIT:
                return "exited";
            case Geofence.GEOFENCE_TRANSITION_DWELL:
                return "dwelling";
            default:
                return "unknown";
        }
    }
    
    private static void showPlaceNotification(Context context, String placeId, String transition) {
        // This would show a notification about place transitions
        // Implementation would be similar to other notification services
        Log.d(TAG, "Place notification: " + transition + " " + placeId);
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        
        // Clean up geofences
        if (geofencingClient != null && geofencePendingIntent != null) {
            geofencingClient.removeGeofences(geofencePendingIntent);
        }
        
        Log.d(TAG, "GeofenceService destroyed");
    }
    
    // Static methods for external control
    public static void initialize(Context context, String userId) {
        Intent intent = new Intent(context, GeofenceService.class);
        intent.putExtra("action", "initialize");
        intent.putExtra("userId", userId);
        context.startService(intent);
    }
    
    public static void addGeofence(Context context, String userId, String geofenceId, 
                                 double latitude, double longitude, float radius, String name) {
        Intent intent = new Intent(context, GeofenceService.class);
        intent.putExtra("action", "add_geofence");
        intent.putExtra("userId", userId);
        intent.putExtra("geofenceId", geofenceId);
        intent.putExtra("latitude", latitude);
        intent.putExtra("longitude", longitude);
        intent.putExtra("radius", radius);
        intent.putExtra("name", name);
        context.startService(intent);
    }
    
    public static void removeGeofence(Context context, String geofenceId) {
        Intent intent = new Intent(context, GeofenceService.class);
        intent.putExtra("action", "remove_geofence");
        intent.putExtra("geofenceId", geofenceId);
        context.startService(intent);
    }
    
    public static void clearAllGeofences(Context context) {
        Intent intent = new Intent(context, GeofenceService.class);
        intent.putExtra("action", "clear_all");
        context.startService(intent);
    }
}