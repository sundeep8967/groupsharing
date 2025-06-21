package com.sundeep.groupsharing;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) || "android.intent.action.QUICKBOOT_POWERON".equals(action)) {
            Log.d(TAG, "Device booted, evaluating location sharing preference");

            SharedPreferences prefs = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE);
            boolean enabled = prefs.getBoolean("location_sharing_enabled", false);
            String userId = prefs.getString("user_id", null);

            if (enabled && userId != null) {
                Intent serviceIntent = new Intent(context, BackgroundLocationService.class);
                serviceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent);
                } else {
                    context.startService(serviceIntent);
                }
                Log.d(TAG, "BackgroundLocationService restarted for user " + userId);
            } else {
                Log.d(TAG, "Location sharing disabled or userId missing");
            }
        }
    }
}
