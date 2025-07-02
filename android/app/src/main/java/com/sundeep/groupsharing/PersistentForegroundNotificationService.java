package com.sundeep.groupsharing;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

/**
 * Persistent Foreground Notification Service
 * 
 * This service manages persistent foreground notifications.
 * It delegates to the BackgroundLocationService for actual implementation.
 */
public class PersistentForegroundNotificationService extends Service {
    private static final String TAG = "PersistentForegroundNotificationService";
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "PersistentForegroundNotificationService created");
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "PersistentForegroundNotificationService started");
        
        // Delegate to BackgroundLocationService
        if (intent != null) {
            String userId = intent.getStringExtra("userId");
            if (userId != null) {
                Intent backgroundServiceIntent = new Intent(this, BackgroundLocationService.class);
                backgroundServiceIntent.putExtra(BackgroundLocationService.EXTRA_USER_ID, userId);
                startForegroundService(backgroundServiceIntent);
            }
        }
        
        return START_STICKY;
    }
    
    @Override
    public void onDestroy() {
        Log.d(TAG, "PersistentForegroundNotificationService destroyed");
        super.onDestroy();
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}