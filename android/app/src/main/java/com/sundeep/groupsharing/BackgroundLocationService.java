package com.sundeep.groupsharing;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Build;
import android.os.IBinder;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

import android.location.LocationListener;
import android.location.LocationManager;
import android.location.Criteria;
import android.os.PowerManager;
import android.provider.Settings;
import android.net.Uri;
import android.app.Activity;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;

public class BackgroundLocationService extends Service {

    public static final String EXTRA_USER_ID = "USER_ID";
    private static final String CHANNEL_ID = "location_fg";

        private LocationManager locationManager;
    private LocationListener listener;
    private static final String FIREBASE_DB = "group-sharing-9d119";
    private String userId;

    /**
     * Checks if battery optimization is disabled for the app.
     *
     * @param context Application context.
     * @return true if disabled, false otherwise.
     */
    public static boolean isBatteryOptimizationDisabled(Context context) {
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return pm != null && pm.isIgnoringBatteryOptimizations(context.getPackageName());
    }

    /**
     * Prompts the user to disable battery optimization for the app.
     *
     * @param activity An Activity context to start the intent.
     */
    public static void requestDisableBatteryOptimization(Activity activity) {
        Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
        intent.setData(Uri.parse("package:" + activity.getPackageName()));
        activity.startActivity(intent);
    }

    @Override
    public void onCreate() {
        super.onCreate();
                locationManager = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        userId = intent.getStringExtra(EXTRA_USER_ID);
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Location Sharing Active")
                .setContentText("Sharing your location in background")
                .setSmallIcon(getApplicationInfo().icon)
                .build();
        startForeground(1, notification);
        startLocationUpdates();
        return START_STICKY;
    }

        private void startLocationUpdates() {
        listener = new LocationListener() {
            @Override
            public void onLocationChanged(Location location) {
                sendLocationToFirebase(location);
            }
            @Override public void onStatusChanged(String provider,int status,android.os.Bundle extras){}
            @Override public void onProviderEnabled(String provider){}
            @Override public void onProviderDisabled(String provider){}
        };

        Criteria criteria = new Criteria();
        criteria.setAccuracy(Criteria.ACCURACY_FINE);
        criteria.setAltitudeRequired(false);
        criteria.setBearingRequired(false);
        criteria.setCostAllowed(false);
        String provider = locationManager.getBestProvider(criteria, true);
        long minTime = 10000; // 10s
        float minDistance = 5; // meters
        try {
            if (provider != null) {
                locationManager.requestLocationUpdates(provider, minTime, minDistance, listener);
            } else {
                // fallback to GPS
                locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, minTime, minDistance, listener);
            }
        } catch (SecurityException ignored) {
        }
    }

    private void sendLocationToFirebase(Location loc) {
        try {
            String path = String.format(Locale.US, "https://%s.firebaseio.com/users/%s/location.json", FIREBASE_DB, userId);
            URL url = new URL(path);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("PATCH");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setDoOutput(true);
            String body = String.format(Locale.US, "{\"lat\":%f,\"lng\":%f,\"timestamp\":%d}", loc.getLatitude(), loc.getLongitude(), System.currentTimeMillis());
            OutputStream os = conn.getOutputStream();
            os.write(body.getBytes());
            os.flush();
            os.close();
            conn.getInputStream().close();
            conn.disconnect();
        } catch (Exception ignored) {
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "Background Location", NotificationManager.IMPORTANCE_LOW);
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            manager.createNotificationChannel(channel);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
                if (locationManager != null && listener != null) {
            locationManager.removeUpdates(listener);
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
