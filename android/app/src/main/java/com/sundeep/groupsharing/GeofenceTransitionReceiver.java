package com.sundeep.groupsharing;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.util.Log;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;
import java.util.List;

/**
 * Broadcast receiver for geofence transition events
 * Handles geofence enter/exit/dwell events and triggers appropriate actions
 */
public class GeofenceTransitionReceiver extends BroadcastReceiver {
    
    private static final String TAG = "GeofenceTransitionReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(TAG, "Geofence transition received");
        
        GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);
        if (geofencingEvent == null) {
            Log.e(TAG, "Geofencing event is null");
            return;
        }
        
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error: " + geofencingEvent.getErrorCode());
            return;
        }
        
        // Get the transition type
        int geofenceTransition = geofencingEvent.getGeofenceTransition();
        
        // Get the geofences that were triggered
        List<Geofence> triggeringGeofences = geofencingEvent.getTriggeringGeofences();
        if (triggeringGeofences == null || triggeringGeofences.isEmpty()) {
            Log.w(TAG, "No triggering geofences found");
            return;
        }
        
        // Get the location that triggered the event
        Location triggeringLocation = geofencingEvent.getTriggeringLocation();
        
        // Get user ID from intent
        String userId = intent.getStringExtra("userId");
        if (userId == null) {
            Log.e(TAG, "User ID not found in intent");
            return;
        }
        
        // Process each triggered geofence
        for (Geofence geofence : triggeringGeofences) {
            String geofenceId = geofence.getRequestId();
            
            Log.d(TAG, "Processing geofence: " + geofenceId + " - " + getTransitionString(geofenceTransition));
            
            // Handle the geofence transition
            GeofenceService.handleGeofenceTransition(
                context, 
                userId, 
                geofenceId, 
                geofenceTransition, 
                triggeringLocation
            );
        }
    }
    
    private String getTransitionString(int transitionType) {
        switch (transitionType) {
            case Geofence.GEOFENCE_TRANSITION_ENTER:
                return "ENTER";
            case Geofence.GEOFENCE_TRANSITION_EXIT:
                return "EXIT";
            case Geofence.GEOFENCE_TRANSITION_DWELL:
                return "DWELL";
            default:
                return "UNKNOWN";
        }
    }
}