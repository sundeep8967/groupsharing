package com.sundeep.groupsharing;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.os.IBinder;
import android.util.Log;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

/**
 * Native Android Driving Detection Service
 * Detects driving using motion sensors, speed analysis, and location patterns
 * Provides Life360-style driving detection with high accuracy
 */
public class DrivingDetectionService extends Service implements SensorEventListener {
    
    private static final String TAG = "DrivingDetectionService";
    
    // Driving detection thresholds
    private static final float DRIVING_SPEED_THRESHOLD = 5.0f; // m/s (18 km/h)
    private static final float STOPPED_SPEED_THRESHOLD = 1.0f; // m/s (3.6 km/h)
    private static final long DRIVING_CONFIRMATION_TIME = 30000; // 30 seconds
    private static final long STOPPED_CONFIRMATION_TIME = 120000; // 2 minutes
    
    // Motion detection thresholds
    private static final float ACCELERATION_THRESHOLD = 2.0f; // m/s²
    private static final float GYROSCOPE_THRESHOLD = 0.5f; // rad/s
    
    // Data buffers for analysis
    private static final int BUFFER_SIZE = 20;
    private List<Float> speedBuffer = new ArrayList<>();
    private List<Float> accelerationBuffer = new ArrayList<>();
    private List<Location> locationBuffer = new ArrayList<>();
    
    // Sensor management
    private SensorManager sensorManager;
    private Sensor accelerometer;
    private Sensor gyroscope;
    
    // State tracking
    private boolean isDriving = false;
    private boolean isInitialized = false;
    private String currentUserId;
    private long drivingStartTime = 0;
    private double totalDistance = 0.0;
    private float maxSpeed = 0.0f;
    private Location lastLocation;
    
    // Firebase
    private DatabaseReference database;
    
    // Timers
    private Timer drivingConfirmationTimer;
    private Timer stoppedConfirmationTimer;
    private Timer analysisTimer;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "DrivingDetectionService created");
        
        // Initialize sensors
        sensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        
        // Initialize Firebase
        database = FirebaseDatabase.getInstance().getReference();
        
        // Start analysis timer
        startAnalysisTimer();
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            String action = intent.getStringExtra("action");
            currentUserId = intent.getStringExtra("userId");
            
            if ("start".equals(action) && currentUserId != null) {
                startDrivingDetection();
            } else if ("stop".equals(action)) {
                stopDrivingDetection();
            }
        }
        
        return START_STICKY; // Restart if killed
    }
    
    private void startDrivingDetection() {
        if (isInitialized) return;
        
        Log.d(TAG, "Starting driving detection for user: " + currentUserId.substring(0, 8));
        
        // Register sensor listeners
        if (accelerometer != null) {
            sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL);
        }
        if (gyroscope != null) {
            sensorManager.registerListener(this, gyroscope, SensorManager.SENSOR_DELAY_NORMAL);
        }
        
        isInitialized = true;
        Log.d(TAG, "Driving detection started successfully");
    }
    
    private void stopDrivingDetection() {
        Log.d(TAG, "Stopping driving detection");
        
        // Unregister sensor listeners
        sensorManager.unregisterListener(this);
        
        // Cancel timers
        if (drivingConfirmationTimer != null) {
            drivingConfirmationTimer.cancel();
        }
        if (stoppedConfirmationTimer != null) {
            stoppedConfirmationTimer.cancel();
        }
        if (analysisTimer != null) {
            analysisTimer.cancel();
        }
        
        // End current driving session if active
        if (isDriving) {
            endDrivingSession();
        }
        
        isInitialized = false;
    }
    
    @Override
    public void onSensorChanged(SensorEvent event) {
        if (!isInitialized || currentUserId == null) return;
        
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            handleAccelerometerData(event.values);
        } else if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE) {
            handleGyroscopeData(event.values);
        }
    }
    
    private void handleAccelerometerData(float[] values) {
        // Calculate total acceleration magnitude
        float acceleration = (float) Math.sqrt(
            values[0] * values[0] + 
            values[1] * values[1] + 
            values[2] * values[2]
        ) - SensorManager.GRAVITY_EARTH; // Remove gravity
        
        // Add to buffer
        accelerationBuffer.add(Math.abs(acceleration));
        if (accelerationBuffer.size() > BUFFER_SIZE) {
            accelerationBuffer.remove(0);
        }
    }
    
    private void handleGyroscopeData(float[] values) {
        // Calculate total rotation magnitude
        float rotation = (float) Math.sqrt(
            values[0] * values[0] + 
            values[1] * values[1] + 
            values[2] * values[2]
        );
        
        // Log significant rotation (indicating vehicle movement)
        if (rotation > GYROSCOPE_THRESHOLD) {
            Log.d(TAG, "Significant rotation detected: " + rotation);
        }
    }
    
    public void onLocationUpdate(Location location) {
        if (!isInitialized || currentUserId == null) return;
        
        // Add location to buffer
        locationBuffer.add(location);
        if (locationBuffer.size() > BUFFER_SIZE) {
            locationBuffer.remove(0);
        }
        
        // Calculate speed
        float speed = location.hasSpeed() ? location.getSpeed() : 0.0f;
        speedBuffer.add(speed);
        if (speedBuffer.size() > BUFFER_SIZE) {
            speedBuffer.remove(0);
        }
        
        // Update max speed if driving
        if (isDriving && speed > maxSpeed) {
            maxSpeed = speed;
        }
        
        // Calculate distance if driving
        if (isDriving && lastLocation != null) {
            float distance = lastLocation.distanceTo(location);
            totalDistance += distance;
        }
        
        lastLocation = location;
        
        // Trigger driving analysis
        analyzeDrivingState();
    }
    
    private void startAnalysisTimer() {
        analysisTimer = new Timer();
        analysisTimer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                analyzeDrivingState();
            }
        }, 5000, 5000); // Analyze every 5 seconds
    }
    
    private void analyzeDrivingState() {
        if (speedBuffer.isEmpty() || accelerationBuffer.isEmpty()) return;
        
        // Calculate average speed
        float avgSpeed = 0;
        for (float speed : speedBuffer) {
            avgSpeed += speed;
        }
        avgSpeed /= speedBuffer.size();
        
        // Calculate average acceleration
        float avgAcceleration = 0;
        for (float acc : accelerationBuffer) {
            avgAcceleration += acc;
        }
        avgAcceleration /= accelerationBuffer.size();
        
        Log.d(TAG, "Analysis - Speed: " + avgSpeed + " m/s, Acceleration: " + avgAcceleration + " m/s²");
        
        // Determine driving state
        boolean shouldBeDriving = avgSpeed > DRIVING_SPEED_THRESHOLD && 
                                 avgAcceleration > ACCELERATION_THRESHOLD;
        boolean shouldBeStopped = avgSpeed < STOPPED_SPEED_THRESHOLD;
        
        if (!isDriving && shouldBeDriving) {
            // Potentially started driving
            if (drivingConfirmationTimer == null) {
                drivingConfirmationTimer = new Timer();
                drivingConfirmationTimer.schedule(new TimerTask() {
                    @Override
                    public void run() {
                        startDrivingSession();
                        drivingConfirmationTimer = null;
                    }
                }, DRIVING_CONFIRMATION_TIME);
            }
        } else if (isDriving && shouldBeStopped) {
            // Potentially stopped driving
            if (stoppedConfirmationTimer == null) {
                stoppedConfirmationTimer = new Timer();
                stoppedConfirmationTimer.schedule(new TimerTask() {
                    @Override
                    public void run() {
                        endDrivingSession();
                        stoppedConfirmationTimer = null;
                    }
                }, STOPPED_CONFIRMATION_TIME);
            }
        } else {
            // Cancel pending timers if conditions changed
            if (drivingConfirmationTimer != null) {
                drivingConfirmationTimer.cancel();
                drivingConfirmationTimer = null;
            }
            if (stoppedConfirmationTimer != null) {
                stoppedConfirmationTimer.cancel();
                stoppedConfirmationTimer = null;
            }
        }
    }
    
    private void startDrivingSession() {
        if (isDriving) return;
        
        Log.d(TAG, "Starting driving session");
        isDriving = true;
        drivingStartTime = System.currentTimeMillis();
        totalDistance = 0.0;
        maxSpeed = 0.0f;
        
        // Update Firebase
        Map<String, Object> drivingData = new HashMap<>();
        drivingData.put("isDriving", true);
        drivingData.put("drivingStartTime", drivingStartTime);
        drivingData.put("source", "android_native_driving_detection");
        
        database.child("users").child(currentUserId).child("driving").updateChildren(drivingData);
        
        // Notify Flutter layer
        notifyFlutter("driving_started", drivingData);
    }
    
    private void endDrivingSession() {
        if (!isDriving) return;
        
        Log.d(TAG, "Ending driving session");
        long endTime = System.currentTimeMillis();
        long duration = endTime - drivingStartTime;
        
        // Create driving session data
        Map<String, Object> sessionData = new HashMap<>();
        sessionData.put("startTime", drivingStartTime);
        sessionData.put("endTime", endTime);
        sessionData.put("duration", duration);
        sessionData.put("distance", totalDistance);
        sessionData.put("maxSpeed", maxSpeed);
        sessionData.put("averageSpeed", totalDistance / (duration / 1000.0));
        sessionData.put("source", "android_native_driving_detection");
        
        // Save to Firebase
        database.child("users").child(currentUserId).child("drivingSessions").push().setValue(sessionData);
        
        // Update current driving status
        Map<String, Object> drivingData = new HashMap<>();
        drivingData.put("isDriving", false);
        drivingData.put("lastDrivingSession", sessionData);
        
        database.child("users").child(currentUserId).child("driving").updateChildren(drivingData);
        
        // Reset state
        isDriving = false;
        drivingStartTime = 0;
        totalDistance = 0.0;
        maxSpeed = 0.0f;
        
        // Notify Flutter layer
        notifyFlutter("driving_ended", sessionData);
    }
    
    private void notifyFlutter(String event, Map<String, Object> data) {
        // This would typically use a method channel to notify Flutter
        // For now, we'll just log the event
        Log.d(TAG, "Flutter notification: " + event + " - " + data.toString());
    }
    
    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        // Handle accuracy changes if needed
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        stopDrivingDetection();
        Log.d(TAG, "DrivingDetectionService destroyed");
    }
    
    // Static methods for external control
    public static void startService(Context context, String userId) {
        Intent intent = new Intent(context, DrivingDetectionService.class);
        intent.putExtra("action", "start");
        intent.putExtra("userId", userId);
        context.startService(intent);
    }
    
    public static void stopService(Context context) {
        Intent intent = new Intent(context, DrivingDetectionService.class);
        intent.putExtra("action", "stop");
        context.startService(intent);
    }
}