package com.sundeep.groupsharing;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

/**
 * PushMessagingService
 *
 * Uses FCM high-priority data messages to resurrect the background location
 * service on OEMs that aggressively kill background tasks. When the backend
 * detects a stale heartbeat for a user, it can send a silent data message
 * with { action: "restart_service" } to this device to ensure the
 * foreground location service is brought back immediately.
 */
public class PushMessagingService extends FirebaseMessagingService {
    private static final String TAG = "PushMessagingService";
    private static final String PREFS_NAME = "location_service_prefs";
    private static final String KEY_WAS_TRACKING = "was_tracking";
    private static final String KEY_USER_ID = "user_id";

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        try {
            if (remoteMessage == null || remoteMessage.getData() == null) {
                return;
            }

            String action = remoteMessage.getData().get("action");
            if (action == null) {
                return;
            }

            Log.d(TAG, "FCM data message action=" + action);

            if ("restart_service".equalsIgnoreCase(action) ||
                "heartbeat".equalsIgnoreCase(action) ||
                "start_tracking".equalsIgnoreCase(action)) {

                SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                boolean wasTracking = prefs.getBoolean(KEY_WAS_TRACKING, false);
                String userId = prefs.getString(KEY_USER_ID, null);

                if (wasTracking && userId != null && !userId.isEmpty()) {
                    Log.d(TAG, "Resurrecting BackgroundLocationService for user=" + userId.substring(0, Math.min(8, userId.length())));

                    Intent svc = new Intent(this, BackgroundLocationService.class);
                    svc.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(svc);
                    } else {
                        startService(svc);
                    }
                } else {
                    Log.d(TAG, "No tracking state to restore; ignoring restart request");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error handling FCM message: " + e.getMessage());
        }
    }
}


