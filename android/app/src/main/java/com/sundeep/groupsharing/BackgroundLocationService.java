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

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;

public class BackgroundLocationService extends Service {

    public static final String EXTRA_USER_ID = "USER_ID";
    private static final String CHANNEL_ID = "location_fg";

    private FusedLocationProviderClient fusedClient;
    private static final String FIREBASE_DB = "group-sharing-9d119";
    private LocationCallback callback;
    private String userId;

    @Override
    public void onCreate() {
        super.onCreate();
        fusedClient = LocationServices.getFusedLocationProviderClient(this);
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
        LocationRequest req = LocationRequest.create();
        req.setInterval(10000);
        req.setFastestInterval(5000);
        req.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);

        callback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                if (locationResult == null) return;
                for (Location loc : locationResult.getLocations()) {
                    sendLocationToFirebase(loc);
                }
            }
        };
        fusedClient.requestLocationUpdates(req, callback, null);
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
        if (fusedClient != null && callback != null) {
            fusedClient.removeLocationUpdates(callback);
        }
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
