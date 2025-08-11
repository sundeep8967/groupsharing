package com.example.groupsharing

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Hardware Sensor Fusion Detector
 * 
 * This class uses multiple hardware sensors to detect user movement and context:
 * 1. Accelerometer - Detects movement start/stop and intensity
 * 2. Gyroscope - Detects orientation changes and rotation
 * 3. Magnetometer - Detects direction changes and compass heading
 * 4. Barometer - Detects elevation changes (stairs, hills, buildings)
 * 5. Ambient Light - Detects indoor/outdoor transitions
 * 
 * Benefits:
 * - Ultra-low battery usage (hardware sensors are very efficient)
 * - Works when GPS/Network unavailable
 * - Instant movement detection (no delay)
 * - Rich context information (walking vs driving vs stairs)
 * - Works in all environments (indoor, underground, etc.)
 */
class SensorFusionDetector private constructor() : SensorEventListener {
    
    companion object {
        private const val TAG = "SensorFusionDetector"
        
        @Volatile
        private var INSTANCE: SensorFusionDetector? = null
        
        fun getInstance(): SensorFusionDetector {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SensorFusionDetector().also { INSTANCE = it }
            }
        }
        
        // Static method channel for communication with Flutter
        @JvmField
        var methodChannel: MethodChannel? = null
        
        // Movement detection thresholds
        private const val ACCELEROMETER_THRESHOLD = 2.0f // m/s²
        private const val GYROSCOPE_THRESHOLD = 0.5f // rad/s
        private const val MAGNETOMETER_THRESHOLD = 5.0f // μT
        private const val BAROMETER_THRESHOLD = 3.0f // hPa (≈ 3 meters elevation)
        private const val LIGHT_THRESHOLD = 100.0f // lux
        
        // Sensor sampling rates
        private const val SENSOR_DELAY = SensorManager.SENSOR_DELAY_NORMAL
        
        // Movement analysis windows
        private const val MOVEMENT_WINDOW_MS = 5000L // 5 seconds
        private const val STILLNESS_WINDOW_MS = 30000L // 30 seconds
    }
    
    private var sensorManager: SensorManager? = null
    private var isMonitoring = false
    
    // Sensors
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null
    private var magnetometer: Sensor? = null
    private var barometer: Sensor? = null
    private var lightSensor: Sensor? = null
    
    // Sensor data
    private var lastAcceleration = FloatArray(3)
    private var lastGyroscope = FloatArray(3)
    private var lastMagnetometer = FloatArray(3)
    private var lastPressure = 0f
    private var lastLight = 0f
    
    // Movement detection state
    private var movementStartTime = 0L
    private var lastMovementTime = 0L
    private var isMoving = false
    private var movementIntensity = 0f
    
    // Context detection
    private var isIndoor = true
    private var currentElevation = 0f
    private var isClimbingStairs = false
    private var currentDirection = 0f
    
    // Analysis buffers
    private val accelerationBuffer = mutableListOf<Float>()
    private val gyroscopeBuffer = mutableListOf<Float>()
    private val pressureBuffer = mutableListOf<Float>()
    
    /**
     * Initialize sensor fusion detector
     */
    fun initialize(context: Context): Boolean {
        try {
            sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            
            // Initialize sensors
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            gyroscope = sensorManager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            magnetometer = sensorManager?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            barometer = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
            lightSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LIGHT)
            
            // Log available sensors
            Log.d(TAG, "Sensor availability:")
            Log.d(TAG, "  Accelerometer: ${accelerometer != null}")
            Log.d(TAG, "  Gyroscope: ${gyroscope != null}")
            Log.d(TAG, "  Magnetometer: ${magnetometer != null}")
            Log.d(TAG, "  Barometer: ${barometer != null}")
            Log.d(TAG, "  Light Sensor: ${lightSensor != null}")
            
            Log.d(TAG, "Sensor Fusion Detector initialized")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Sensor Fusion Detector", e)
            return false
        }
    }
    
    /**
     * Start sensor monitoring
     */
    fun startMonitoring(): Boolean {
        if (isMonitoring) return true
        
        try {
            var registeredSensors = 0
            
            // Register accelerometer (most important for movement detection)
            accelerometer?.let {
                sensorManager?.registerListener(this, it, SENSOR_DELAY)
                registeredSensors++
            }
            
            // Register gyroscope (orientation changes)
            gyroscope?.let {
                sensorManager?.registerListener(this, it, SENSOR_DELAY)
                registeredSensors++
            }
            
            // Register magnetometer (direction changes)
            magnetometer?.let {
                sensorManager?.registerListener(this, it, SENSOR_DELAY)
                registeredSensors++
            }
            
            // Register barometer (elevation changes)
            barometer?.let {
                sensorManager?.registerListener(this, it, SENSOR_DELAY)
                registeredSensors++
            }
            
            // Register light sensor (indoor/outdoor detection)
            lightSensor?.let {
                sensorManager?.registerListener(this, it, SENSOR_DELAY)
                registeredSensors++
            }
            
            if (registeredSensors > 0) {
                isMonitoring = true
                Log.d(TAG, "Started monitoring $registeredSensors sensors")
                return true
            } else {
                Log.e(TAG, "No sensors available for monitoring")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start sensor monitoring", e)
            return false
        }
    }
    
    /**
     * Stop sensor monitoring
     */
    fun stopMonitoring() {
        if (!isMonitoring) return
        
        try {
            sensorManager?.unregisterListener(this)
            isMonitoring = false
            
            // Clear buffers
            accelerationBuffer.clear()
            gyroscopeBuffer.clear()
            pressureBuffer.clear()
            
            Log.d(TAG, "Stopped sensor monitoring")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping sensor monitoring", e)
        }
    }
    
    /**
     * Handle sensor data changes
     */
    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> handleAccelerometerData(event)
            Sensor.TYPE_GYROSCOPE -> handleGyroscopeData(event)
            Sensor.TYPE_MAGNETIC_FIELD -> handleMagnetometerData(event)
            Sensor.TYPE_PRESSURE -> handleBarometerData(event)
            Sensor.TYPE_LIGHT -> handleLightSensorData(event)
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Handle accuracy changes if needed
    }
    
    /**
     * Handle accelerometer data (movement detection)
     */
    private fun handleAccelerometerData(event: SensorEvent) {
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        
        // Calculate acceleration magnitude (remove gravity)
        val acceleration = sqrt(x * x + y * y + z * z) - SensorManager.GRAVITY_EARTH
        val accelerationMagnitude = abs(acceleration)
        
        // Add to buffer for analysis
        accelerationBuffer.add(accelerationMagnitude)
        if (accelerationBuffer.size > 50) { // Keep last 50 readings
            accelerationBuffer.removeAt(0)
        }
        
        // Detect movement start/stop
        if (accelerationMagnitude > ACCELEROMETER_THRESHOLD) {
            if (!isMoving) {
                // Movement started
                isMoving = true
                movementStartTime = System.currentTimeMillis()
                Log.d(TAG, "Movement started (acceleration: ${accelerationMagnitude.toInt()})")
                sendMovementEvent("MOVEMENT_STARTED", mapOf(
                    "intensity" to accelerationMagnitude,
                    "type" to "accelerometer"
                ))
            }
            lastMovementTime = System.currentTimeMillis()
            movementIntensity = accelerationMagnitude
        } else {
            // Check if movement stopped
            val timeSinceMovement = System.currentTimeMillis() - lastMovementTime
            if (isMoving && timeSinceMovement > STILLNESS_WINDOW_MS) {
                isMoving = false
                Log.d(TAG, "Movement stopped (stillness for ${timeSinceMovement/1000}s)")
                sendMovementEvent("MOVEMENT_STOPPED", mapOf(
                    "duration" to (System.currentTimeMillis() - movementStartTime),
                    "type" to "accelerometer"
                ))
            }
        }
        
        // Analyze movement pattern
        analyzeMovementPattern()
        
        lastAcceleration = event.values.clone()
    }
    
    /**
     * Handle gyroscope data (orientation changes)
     */
    private fun handleGyroscopeData(event: SensorEvent) {
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        
        // Calculate rotation magnitude
        val rotationMagnitude = sqrt(x * x + y * y + z * z)
        
        // Add to buffer
        gyroscopeBuffer.add(rotationMagnitude)
        if (gyroscopeBuffer.size > 30) {
            gyroscopeBuffer.removeAt(0)
        }
        
        // Detect significant orientation changes
        if (rotationMagnitude > GYROSCOPE_THRESHOLD) {
            Log.d(TAG, "Orientation change detected (rotation: ${rotationMagnitude.toInt()})")
            sendMovementEvent("ORIENTATION_CHANGED", mapOf(
                "rotation" to rotationMagnitude,
                "type" to "gyroscope"
            ))
        }
        
        lastGyroscope = event.values.clone()
    }
    
    /**
     * Handle magnetometer data (direction changes)
     */
    private fun handleMagnetometerData(event: SensorEvent) {
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        
        // Calculate magnetic field magnitude
        val magneticMagnitude = sqrt(x * x + y * y + z * z)
        
        // Detect direction changes
        val lastMagnitude = sqrt(
            lastMagnetometer[0] * lastMagnetometer[0] +
            lastMagnetometer[1] * lastMagnetometer[1] +
            lastMagnetometer[2] * lastMagnetometer[2]
        )
        
        if (lastMagnitude > 0 && abs(magneticMagnitude - lastMagnitude) > MAGNETOMETER_THRESHOLD) {
            Log.d(TAG, "Direction change detected (magnetic: ${magneticMagnitude.toInt()})")
            sendMovementEvent("DIRECTION_CHANGED", mapOf(
                "magneticField" to magneticMagnitude,
                "type" to "magnetometer"
            ))
        }
        
        lastMagnetometer = event.values.clone()
    }
    
    /**
     * Handle barometer data (elevation changes)
     */
    private fun handleBarometerData(event: SensorEvent) {
        val pressure = event.values[0]
        
        // Add to buffer
        pressureBuffer.add(pressure)
        if (pressureBuffer.size > 20) {
            pressureBuffer.removeAt(0)
        }
        
        // Detect elevation changes
        if (lastPressure > 0) {
            val pressureChange = abs(pressure - lastPressure)
            
            if (pressureChange > BAROMETER_THRESHOLD) {
                // Convert pressure change to approximate elevation change
                val elevationChange = pressureChange * 8.3f // Rough conversion: 1 hPa ≈ 8.3m
                
                Log.d(TAG, "Elevation change detected: ${elevationChange.toInt()}m")
                
                // Detect stair climbing
                if (elevationChange > 10f && isMoving) {
                    isClimbingStairs = true
                    sendMovementEvent("STAIRS_DETECTED", mapOf(
                        "elevationChange" to elevationChange,
                        "type" to "barometer"
                    ))
                }
            }
        }
        
        lastPressure = pressure
    }
    
    /**
     * Handle light sensor data (indoor/outdoor detection)
     */
    private fun handleLightSensorData(event: SensorEvent) {
        val lightLevel = event.values[0]
        
        // Detect indoor/outdoor transitions
        val wasIndoor = isIndoor
        isIndoor = lightLevel < LIGHT_THRESHOLD
        
        if (wasIndoor != isIndoor) {
            val transition = if (isIndoor) "ENTERED_INDOOR" else "ENTERED_OUTDOOR"
            Log.d(TAG, "Environment transition: $transition (light: ${lightLevel.toInt()} lux)")
            
            sendMovementEvent(transition, mapOf(
                "lightLevel" to lightLevel,
                "isIndoor" to isIndoor,
                "type" to "light"
            ))
        }
        
        lastLight = lightLevel
    }
    
    /**
     * Analyze movement patterns from sensor data
     */
    private fun analyzeMovementPattern() {
        if (accelerationBuffer.size < 10) return
        
        // Calculate movement statistics
        val avgAcceleration = accelerationBuffer.average().toFloat()
        val maxAcceleration = accelerationBuffer.maxOrNull() ?: 0f
        val variance = accelerationBuffer.map { (it - avgAcceleration) * (it - avgAcceleration) }.average().toFloat()
        
        // Classify movement type
        val movementType = when {
            maxAcceleration > 8f && variance > 4f -> "RUNNING"
            maxAcceleration > 4f && variance > 2f -> "WALKING"
            maxAcceleration > 2f && variance < 1f -> "VEHICLE"
            maxAcceleration < 1f -> "STILL"
            else -> "UNKNOWN"
        }
        
        // Send movement classification
        sendMovementEvent("MOVEMENT_CLASSIFIED", mapOf(
            "movementType" to movementType,
            "intensity" to avgAcceleration,
            "variance" to variance,
            "type" to "analysis"
        ))
    }
    
    /**
     * Send movement event to Flutter
     */
    private fun sendMovementEvent(eventType: String, data: Map<String, Any>) {
        try {
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onSensorMovementDetected", mapOf(
                    "eventType" to eventType,
                    "timestamp" to System.currentTimeMillis(),
                    "data" to data,
                    "context" to getCurrentContext()
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending movement event to Flutter", e)
        }
    }
    
    /**
     * Get current movement context
     */
    private fun getCurrentContext(): Map<String, Any> {
        return mapOf(
            "isMoving" to isMoving,
            "movementIntensity" to movementIntensity,
            "isIndoor" to isIndoor,
            "isClimbingStairs" to isClimbingStairs,
            "lightLevel" to lastLight,
            "pressure" to lastPressure
        )
    }
    
    /**
     * Get current sensor fusion state
     */
    fun getCurrentState(): Map<String, Any> {
        return mapOf(
            "isMonitoring" to isMonitoring,
            "isMoving" to isMoving,
            "movementIntensity" to movementIntensity,
            "isIndoor" to isIndoor,
            "isClimbingStairs" to isClimbingStairs,
            "sensorsAvailable" to mapOf(
                "accelerometer" to (accelerometer != null),
                "gyroscope" to (gyroscope != null),
                "magnetometer" to (magnetometer != null),
                "barometer" to (barometer != null),
                "lightSensor" to (lightSensor != null)
            )
        )
    }
}