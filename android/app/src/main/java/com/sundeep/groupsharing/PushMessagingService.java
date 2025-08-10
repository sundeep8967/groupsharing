package com.sundeep.groupsharing;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import com.google.firebase.FirebaseApp;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

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
                "start_tracking".equalsIgnoreCase(action) ||
                "revive_service".equalsIgnoreCase(action)) {

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

                    // Ensure WorkManager watchdog is scheduled
                    try {
                        LocationWatchdogWorker.schedulePeriodic(getApplicationContext());
                    } catch (Throwable t) {
                        Log.w(TAG, "Failed to schedule WorkManager watchdog from FCM: " + t.getMessage());
                    }

                    // Log revival confirmation (RTDB + optional HTTP)
                    try {
                        sendRevivalConfirmation(userId, "fcm");
                    } catch (Exception e) {
                        Log.w(TAG, "Revival confirmation failed: " + e.getMessage());
                    }
                } else {
                    Log.d(TAG, "No tracking state to restore; ignoring restart request");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error handling FCM message: " + e.getMessage());
        }
    }

    @Override
    public void onNewToken(String token) {
        super.onNewToken(token);
        Log.d(TAG, "New FCM token: " + token);
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String userId = prefs.getString(KEY_USER_ID, null);

            if (userId == null || userId.isEmpty()) {
                Log.w(TAG, "onNewToken: no userId in prefs; skipping RTDB update");
                return;
            }

            ensureFirebase();
            FirebaseDatabase db = FirebaseDatabase.getInstance();
            DatabaseReference userRef = db.getReference("users").child(userId);
            userRef.child("fcmToken").setValue(token);
            userRef.child("lastTokenRefresh").setValue(System.currentTimeMillis());
            Log.d(TAG, "FCM token saved to RTDB for user=" + userId.substring(0, Math.min(8, userId.length())));
        } catch (Throwable t) {
            Log.e(TAG, "Failed to persist FCM token: " + t.getMessage());
        }
    }

    private void ensureFirebase() {
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this);
                Log.d(TAG, "Firebase initialized in PushMessagingService");
            }
        } catch (Throwable t) {
            Log.w(TAG, "ensureFirebase: " + t.getMessage());
        }
    }

    private void sendRevivalConfirmation(String userId, String source) {
        // Write to RTDB
        try {
            ensureFirebase();
            FirebaseDatabase db = FirebaseDatabase.getInstance();
            DatabaseReference userRef = db.getReference("users").child(userId).child("revivals");
            long ts = System.currentTimeMillis();
            DatabaseReference revRef = userRef.child(String.valueOf(ts));
            revRef.child("source").setValue(source);
            revRef.child("timestamp").setValue(ts);
        } catch (Throwable t) {
            Log.w(TAG, "RTDB revival log failed: " + t.getMessage());
        }

        // Optional HTTP POST to external endpoint if string resource 'revival_confirm_url' is defined
        try {
            String urlStr = null;
            int id = getResources().getIdentifier("revival_confirm_url", "string", getPackageName());
            if (id != 0) {
                urlStr = getString(id);
            }
            if (urlStr == null || urlStr.isEmpty()) return;

            final String finalUrlStr = urlStr;
            new Thread(() -> {
                try {
                    URL url = new URL(finalUrlStr);
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setRequestMethod("POST");
                    conn.setConnectTimeout(10000);
                    conn.setReadTimeout(10000);
                    conn.setDoOutput(true);
                    conn.setRequestProperty("Content-Type", "application/json");

                    String deviceId = Settings.Secure.getString(getContentResolver(), Settings.Secure.ANDROID_ID);
                    JSONObject body = new JSONObject();
                    body.put("user_id", userId);
                    body.put("device_id", deviceId);
                    body.put("source", source);
                    body.put("timestamp", System.currentTimeMillis());

                    byte[] bytes = body.toString().getBytes();
                    conn.setFixedLengthStreamingMode(bytes.length);
                    try (OutputStream os = conn.getOutputStream()) {
                        os.write(bytes);
                    }

                    int code = conn.getResponseCode();
                    Log.d(TAG, "Revival confirmation HTTP status=" + code);
                    conn.disconnect();
                } catch (Exception e) {
                    Log.w(TAG, "Revival confirmation HTTP failed: " + e.getMessage());
                }
            }).start();
        } catch (Throwable t) {
            Log.w(TAG, "Optional HTTP confirmation skipped: " + t.getMessage());
        }
    }
}


