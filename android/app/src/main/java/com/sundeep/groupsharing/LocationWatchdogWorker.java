package com.sundeep.groupsharing;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import java.util.concurrent.TimeUnit;

/**
 * WorkManager-based watchdog which periodically checks whether
 * {@link BackgroundLocationService} is running and restarts it if needed.
 */
public class LocationWatchdogWorker extends Worker {
    private static final String TAG = "LocationWatchdogWorker";
    private static final String UNIQUE_WORK_NAME = "location_watchdog_periodic";

    public LocationWatchdogWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        try {
            Context context = getApplicationContext();
            if (!isServiceRunning(context, BackgroundLocationService.class)) {
                Log.w(TAG, "BackgroundLocationService not running. Attempting restart from WorkManager.");
                Intent svc = new Intent(context, BackgroundLocationService.class);
                // Try to restore last user id saved by BootReceiver
                String userId = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
                        .getString("user_id", null);
                if (userId != null && !userId.isEmpty()) {
                    svc.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(svc);
                    } else {
                        context.startService(svc);
                    }
                    Log.i(TAG, "Service restarted by WorkManager watchdog");
                } else {
                    Log.i(TAG, "No saved tracking state; skipping restart");
                }
            } else {
                Log.d(TAG, "BackgroundLocationService is running.");
            }
            return Result.success();
        } catch (Throwable t) {
            Log.e(TAG, "Watchdog error: " + t.getMessage());
            return Result.retry();
        }
    }

    private static boolean isServiceRunning(Context context, Class<?> serviceClass) {
        ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        if (manager != null) {
            for (ActivityManager.RunningServiceInfo service : manager.getRunningServices(Integer.MAX_VALUE)) {
                if (serviceClass.getName().equals(service.service.getClassName())) {
                    return true;
                }
            }
        }
        return false;
    }

    public static void schedulePeriodic(Context context) {
        try {
            Constraints constraints = new Constraints.Builder()
                    .setRequiresBatteryNotLow(false)
                    .setRequiresCharging(false)
                    .build();

            PeriodicWorkRequest request = new PeriodicWorkRequest.Builder(
                    LocationWatchdogWorker.class,
                    15, TimeUnit.MINUTES)
                    .setConstraints(constraints)
                    .build();

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    UNIQUE_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
            );
            Log.d(TAG, "Scheduled WorkManager watchdog (15m interval)");
        } catch (Throwable t) {
            Log.w(TAG, "Failed to schedule WorkManager watchdog: " + t.getMessage());
        }
    }
}
