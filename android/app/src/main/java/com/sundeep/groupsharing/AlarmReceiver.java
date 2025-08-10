package com.sundeep.groupsharing;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

/**
 * AlarmReceiver
 *
 * Wakes up periodically (exact + allow while idle) to ensure the foreground
 * notification and background location services are running, and re-schedules itself.
 */
public class AlarmReceiver extends BroadcastReceiver {
    private static final String TAG = "AlarmReceiver";
    public static final String ACTION_HEARTBEAT = "com.sundeep.groupsharing.ACTION_HEARTBEAT";
    private static final String PREFS_NAME = "location_service_prefs";
    private static final String KEY_WAS_TRACKING = "was_tracking";
    private static final String KEY_USER_ID = "user_id";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : null;
        Log.d(TAG, "onReceive action=" + action);

        if (ACTION_HEARTBEAT.equals(action)) {
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            boolean wasTracking = prefs.getBoolean(KEY_WAS_TRACKING, false);
            String userId = prefs.getString(KEY_USER_ID, null);

            if (wasTracking && userId != null && !userId.isEmpty()) {
                try {
                    // Ensure background location service is running
                    Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
                    serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent);
                    } else {
                        context.startService(serviceIntent);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error starting BackgroundLocationService from alarm: " + e.getMessage());
                }

                // Re-schedule next heartbeat
                scheduleNext(context, 15 * 60 * 1000L); // 15 minutes
            } else {
                Log.d(TAG, "Not rescheduling alarm - not tracking");
            }
        }
    }

    public static void scheduleNext(Context context, long intervalMs) {
        try {
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) return;

            Intent intent = new Intent(context, AlarmReceiver.class);
            intent.setAction(ACTION_HEARTBEAT);
            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            long triggerAt = System.currentTimeMillis() + intervalMs;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent);
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent);
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent);
            }
            Log.d(TAG, "Heartbeat alarm scheduled in " + intervalMs + " ms");
        } catch (Exception e) {
            Log.e(TAG, "Error scheduling alarm: " + e.getMessage());
        }
    }

    public static void cancel(Context context) {
        try {
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) return;
            Intent intent = new Intent(context, AlarmReceiver.class);
            intent.setAction(ACTION_HEARTBEAT);
            PendingIntent pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );
            alarmManager.cancel(pendingIntent);
            Log.d(TAG, "Heartbeat alarm cancelled");
        } catch (Exception e) {
            Log.e(TAG, "Error cancelling alarm: " + e.getMessage());
        }
    }
}


