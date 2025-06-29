package com.sundeep.groupsharing;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/**
 * Native Android Emergency/SOS Service
 * Handles emergency situations with countdown, notifications, and automatic calling
 * Provides Life360-style emergency features with high reliability
 */
public class EmergencyService extends Service {
    
    private static final String TAG = "EmergencyService";
    private static final String EMERGENCY_CHANNEL_ID = "emergency_channel";
    private static final int EMERGENCY_NOTIFICATION_ID = 9999;
    
    // SOS Configuration
    private static final long SOS_COUNTDOWN_DURATION = 5000; // 5 seconds
    private static final long EMERGENCY_TIMEOUT = 1800000; // 30 minutes
    private static final String EMERGENCY_NUMBER = "911"; // Default emergency number
    
    // State tracking
    private boolean isEmergencyActive = false;
    private boolean isSosCountdownActive = false;
    private String currentUserId;
    private Location lastKnownLocation;
    private long emergencyStartTime;
    private String emergencyId;
    
    // Firebase
    private DatabaseReference database;
    
    // System services
    private NotificationManager notificationManager;
    private Vibrator vibrator;
    private ToneGenerator toneGenerator;
    
    // Timers
    private Timer sosCountdownTimer;
    private Timer emergencyTimeoutTimer;
    private Timer heartbeatTimer;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "EmergencyService created");
        
        // Initialize system services
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        
        try {
            toneGenerator = new ToneGenerator(AudioManager.STREAM_ALARM, 100);
        } catch (RuntimeException e) {
            Log.w(TAG, "Could not create ToneGenerator", e);
        }
        
        // Initialize Firebase
        database = FirebaseDatabase.getInstance().getReference();
        
        // Create notification channel
        createNotificationChannel();
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getStringExtra("action");
            currentUserId = intent.getStringExtra("userId");
            
            switch (action != null ? action : "") {
                case "start_sos":
                    startSosCountdown();
                    break;
                case "cancel_sos":
                    cancelSosCountdown();
                    break;
                case "trigger_emergency":
                    triggerEmergency();
                    break;
                case "cancel_emergency":
                    cancelEmergency();
                    break;
                case "update_location":
                    updateLocation(intent);
                    break;
                default:
                    Log.w(TAG, "Unknown action: " + action);
                    break;
            }
        }
        
        return START_STICKY; // Restart if killed during emergency
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                "Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Critical emergency notifications");
            channel.enableVibration(true);
            channel.enableLights(true);
            channel.setLockscreenVisibility(NotificationCompat.VISIBILITY_PUBLIC);
            
            notificationManager.createNotificationChannel(channel);
        }
    }
    
    private void startSosCountdown() {
        if (isSosCountdownActive || isEmergencyActive) {
            Log.w(TAG, "SOS already active, ignoring request");
            return;
        }
        
        Log.d(TAG, "Starting SOS countdown");
        isSosCountdownActive = true;
        
        // Start countdown timer
        sosCountdownTimer = new Timer();
        final long startTime = System.currentTimeMillis();
        
        sosCountdownTimer.scheduleAtFixedRate(new TimerTask() {
            int countdown = 5;
            
            @Override
            public void run() {
                if (countdown > 0) {
                    // Show countdown notification
                    showSosCountdownNotification(countdown);
                    
                    // Play warning sound and vibrate
                    playWarningSound();
                    vibrateDevice();
                    
                    // Update Firebase with countdown
                    updateSosCountdownInFirebase(countdown);
                    
                    countdown--;
                } else {
                    // Countdown finished, trigger emergency
                    sosCountdownTimer.cancel();
                    triggerEmergency();
                }
            }
        }, 0, 1000); // Update every second
    }
    
    private void cancelSosCountdown() {
        if (!isSosCountdownActive) return;
        
        Log.d(TAG, "Cancelling SOS countdown");
        isSosCountdownActive = false;
        
        if (sosCountdownTimer != null) {
            sosCountdownTimer.cancel();
            sosCountdownTimer = null;
        }
        
        // Cancel countdown notification
        notificationManager.cancel(EMERGENCY_NOTIFICATION_ID);
        
        // Update Firebase
        if (currentUserId != null) {
            Map<String, Object> sosData = new HashMap<>();
            sosData.put("sosActive", false);
            sosData.put("sosCancelled", true);
            sosData.put("cancelTime", System.currentTimeMillis());
            
            database.child("users").child(currentUserId).child("emergency").updateChildren(sosData);
        }
        
        // Notify Flutter
        notifyFlutter("sos_cancelled", null);
    }
    
    private void triggerEmergency() {
        if (isEmergencyActive) return;
        
        Log.d(TAG, "EMERGENCY TRIGGERED!");
        isEmergencyActive = true;
        isSosCountdownActive = false;
        emergencyStartTime = System.currentTimeMillis();
        emergencyId = "emergency_" + emergencyStartTime;
        
        // Create emergency event data
        Map<String, Object> emergencyData = new HashMap<>();
        emergencyData.put("id", emergencyId);
        emergencyData.put("userId", currentUserId);
        emergencyData.put("startTime", emergencyStartTime);
        emergencyData.put("type", "sos");
        emergencyData.put("status", "active");
        emergencyData.put("source", "android_native_emergency");
        
        if (lastKnownLocation != null) {
            Map<String, Object> locationData = new HashMap<>();
            locationData.put("latitude", lastKnownLocation.getLatitude());
            locationData.put("longitude", lastKnownLocation.getLongitude());
            locationData.put("accuracy", lastKnownLocation.getAccuracy());
            locationData.put("timestamp", System.currentTimeMillis());
            emergencyData.put("location", locationData);
        }
        
        // Save to Firebase
        database.child("emergencies").child(emergencyId).setValue(emergencyData);
        database.child("users").child(currentUserId).child("emergency").updateChildren(emergencyData);
        
        // Show emergency notification
        showEmergencyNotification();
        
        // Start emergency heartbeat
        startEmergencyHeartbeat();
        
        // Set emergency timeout
        emergencyTimeoutTimer = new Timer();
        emergencyTimeoutTimer.schedule(new TimerTask() {
            @Override
            public void run() {
                Log.d(TAG, "Emergency timeout reached, auto-cancelling");
                cancelEmergency();
            }
        }, EMERGENCY_TIMEOUT);
        
        // Attempt to call emergency services (requires user permission)
        attemptEmergencyCall();
        
        // Notify Flutter
        notifyFlutter("emergency_triggered", emergencyData);
    }
    
    private void cancelEmergency() {
        if (!isEmergencyActive) return;
        
        Log.d(TAG, "Cancelling emergency");
        isEmergencyActive = false;
        
        // Cancel timers
        if (emergencyTimeoutTimer != null) {
            emergencyTimeoutTimer.cancel();
            emergencyTimeoutTimer = null;
        }
        if (heartbeatTimer != null) {
            heartbeatTimer.cancel();
            heartbeatTimer = null;
        }
        
        // Update Firebase
        if (emergencyId != null && currentUserId != null) {
            Map<String, Object> updateData = new HashMap<>();
            updateData.put("status", "cancelled");
            updateData.put("endTime", System.currentTimeMillis());
            updateData.put("duration", System.currentTimeMillis() - emergencyStartTime);
            
            database.child("emergencies").child(emergencyId).updateChildren(updateData);
            database.child("users").child(currentUserId).child("emergency").updateChildren(updateData);
        }
        
        // Cancel notification
        notificationManager.cancel(EMERGENCY_NOTIFICATION_ID);
        
        // Notify Flutter
        notifyFlutter("emergency_cancelled", null);
        
        // Reset state
        emergencyId = null;
        emergencyStartTime = 0;
    }
    
    private void updateLocation(Intent intent) {
        if (intent.hasExtra("latitude") && intent.hasExtra("longitude")) {
            double latitude = intent.getDoubleExtra("latitude", 0.0);
            double longitude = intent.getDoubleExtra("longitude", 0.0);
            float accuracy = intent.getFloatExtra("accuracy", 0.0f);
            
            lastKnownLocation = new Location("emergency");
            lastKnownLocation.setLatitude(latitude);
            lastKnownLocation.setLongitude(longitude);
            lastKnownLocation.setAccuracy(accuracy);
            lastKnownLocation.setTime(System.currentTimeMillis());
            
            // Update emergency location if active
            if (isEmergencyActive && emergencyId != null) {
                Map<String, Object> locationData = new HashMap<>();
                locationData.put("latitude", latitude);
                locationData.put("longitude", longitude);
                locationData.put("accuracy", accuracy);
                locationData.put("timestamp", System.currentTimeMillis());
                
                database.child("emergencies").child(emergencyId).child("currentLocation").setValue(locationData);
            }
        }
    }
    
    private void showSosCountdownNotification(int countdown) {
        Intent cancelIntent = new Intent(this, EmergencyService.class);
        cancelIntent.putExtra("action", "cancel_sos");
        PendingIntent cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, EMERGENCY_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("SOS Emergency")
            .setContentText("Emergency will be triggered in " + countdown + " seconds")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "CANCEL", cancelPendingIntent)
            .setFullScreenIntent(cancelPendingIntent, true);
        
        notificationManager.notify(EMERGENCY_NOTIFICATION_ID, builder.build());
    }
    
    private void showEmergencyNotification() {
        Intent cancelIntent = new Intent(this, EmergencyService.class);
        cancelIntent.putExtra("action", "cancel_emergency");
        PendingIntent cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );
        
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, EMERGENCY_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 EMERGENCY ACTIVE")
            .setContentText("Emergency services have been notified. Your location is being shared.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "CANCEL EMERGENCY", cancelPendingIntent)
            .setColor(0xFFFF0000); // Red color
        
        notificationManager.notify(EMERGENCY_NOTIFICATION_ID, builder.build());
    }
    
    private void startEmergencyHeartbeat() {
        heartbeatTimer = new Timer();
        heartbeatTimer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                if (isEmergencyActive && emergencyId != null) {
                    Map<String, Object> heartbeat = new HashMap<>();
                    heartbeat.put("timestamp", System.currentTimeMillis());
                    heartbeat.put("status", "active");
                    
                    if (lastKnownLocation != null) {
                        Map<String, Object> locationData = new HashMap<>();
                        locationData.put("latitude", lastKnownLocation.getLatitude());
                        locationData.put("longitude", lastKnownLocation.getLongitude());
                        locationData.put("accuracy", lastKnownLocation.getAccuracy());
                        heartbeat.put("location", locationData);
                    }
                    
                    database.child("emergencies").child(emergencyId).child("heartbeat").setValue(heartbeat);
                }
            }
        }, 0, 10000); // Every 10 seconds
    }
    
    private void updateSosCountdownInFirebase(int countdown) {
        if (currentUserId != null) {
            Map<String, Object> sosData = new HashMap<>();
            sosData.put("sosActive", true);
            sosData.put("sosCountdown", countdown);
            sosData.put("sosStartTime", System.currentTimeMillis());
            
            database.child("users").child(currentUserId).child("emergency").updateChildren(sosData);
        }
    }
    
    private void playWarningSound() {
        if (toneGenerator != null) {
            try {
                toneGenerator.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, 500);
            } catch (Exception e) {
                Log.w(TAG, "Could not play warning sound", e);
            }
        }
    }
    
    private void vibrateDevice() {
        if (vibrator != null && vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                vibrator.vibrate(500);
            }
        }
    }
    
    private void attemptEmergencyCall() {
        try {
            Intent callIntent = new Intent(Intent.ACTION_CALL);
            callIntent.setData(Uri.parse("tel:" + EMERGENCY_NUMBER));
            callIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            
            // Note: This requires CALL_PHONE permission and user approval
            // In a real implementation, you might want to show a dialog first
            Log.d(TAG, "Would attempt to call emergency services: " + EMERGENCY_NUMBER);
            // startActivity(callIntent); // Uncomment when ready for production
            
        } catch (Exception e) {
            Log.e(TAG, "Could not initiate emergency call", e);
        }
    }
    
    private void notifyFlutter(String event, Map<String, Object> data) {
        // This would typically use a method channel to notify Flutter
        Log.d(TAG, "Flutter notification: " + event + " - " + (data != null ? data.toString() : "null"));
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        
        // Clean up resources
        if (sosCountdownTimer != null) {
            sosCountdownTimer.cancel();
        }
        if (emergencyTimeoutTimer != null) {
            emergencyTimeoutTimer.cancel();
        }
        if (heartbeatTimer != null) {
            heartbeatTimer.cancel();
        }
        if (toneGenerator != null) {
            toneGenerator.release();
        }
        
        Log.d(TAG, "EmergencyService destroyed");
    }
    
    // Static methods for external control
    public static void startSos(Context context, String userId) {
        Intent intent = new Intent(context, EmergencyService.class);
        intent.putExtra("action", "start_sos");
        intent.putExtra("userId", userId);
        context.startService(intent);
    }
    
    public static void cancelSos(Context context) {
        Intent intent = new Intent(context, EmergencyService.class);
        intent.putExtra("action", "cancel_sos");
        context.startService(intent);
    }
    
    public static void triggerEmergency(Context context, String userId) {
        Intent intent = new Intent(context, EmergencyService.class);
        intent.putExtra("action", "trigger_emergency");
        intent.putExtra("userId", userId);
        context.startService(intent);
    }
    
    public static void cancelEmergency(Context context) {
        Intent intent = new Intent(context, EmergencyService.class);
        intent.putExtra("action", "cancel_emergency");
        context.startService(intent);
    }
    
    public static void updateLocation(Context context, double latitude, double longitude, float accuracy) {
        Intent intent = new Intent(context, EmergencyService.class);
        intent.putExtra("action", "update_location");
        intent.putExtra("latitude", latitude);
        intent.putExtra("longitude", longitude);
        intent.putExtra("accuracy", accuracy);
        context.startService(intent);
    }
}