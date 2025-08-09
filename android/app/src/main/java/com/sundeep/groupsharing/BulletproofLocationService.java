package com.sundeep.groupsharing;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;
import io.flutter.plugin.common.MethodChannel;

/**
 * Bulletproof Location Service
 * 
 * This service provides enhanced location tracking with bulletproof reliability.
 * It's designed to work in conjunction with the BackgroundLocationService.
 */
public class BulletproofLocationService extends Service {
    private static final String TAG = "BulletproofLocationService";
    private static boolean isRunning = false;
    private static MethodChannel methodChannel;
    
    public static void setMethodChannel(MethodChannel channel) {
        methodChannel = channel;
    }
    
    public static boolean isRunning() {
        return isRunning;
    }
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "BulletproofLocationService created");
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "BulletproofLocationService started");
        isRunning = true;
        
        // For now, delegate to BackgroundLocationService
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
        Log.d(TAG, "BulletproofLocationService destroyed");
        isRunning = false;
        super.onDestroy();
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}