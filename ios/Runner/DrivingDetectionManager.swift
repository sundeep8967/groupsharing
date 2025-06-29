import Foundation
import CoreLocation
import CoreMotion
import Firebase
import FirebaseDatabase

/**
 * Native iOS Driving Detection Manager
 * Detects driving using motion sensors, speed analysis, and location patterns
 * Provides Life360-style driving detection with high accuracy
 */
@available(iOS 13.0, *)
class DrivingDetectionManager: NSObject {
    static let shared = DrivingDetectionManager()
    
    // Motion and location managers
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    // State tracking
    private var isInitialized = false
    private var isDriving = false
    private var currentUserId: String?
    private var drivingStartTime: Date?
    private var totalDistance: Double = 0.0
    private var maxSpeed: Double = 0.0
    private var lastLocation: CLLocation?
    
    // Data buffers for analysis
    private var speedBuffer: [Double] = []
    private var accelerationBuffer: [Double] = []
    private var locationBuffer: [CLLocation] = []
    private let bufferSize = 20
    
    // Driving detection thresholds
    private let drivingSpeedThreshold: Double = 5.0 // m/s (18 km/h)
    private let stoppedSpeedThreshold: Double = 1.0 // m/s (3.6 km/h)
    private let drivingConfirmationTime: TimeInterval = 30.0 // 30 seconds
    private let stoppedConfirmationTime: TimeInterval = 120.0 // 2 minutes
    
    // Motion detection thresholds
    private let accelerationThreshold: Double = 2.0 // m/s²
    private let gyroscopeThreshold: Double = 0.5 // rad/s
    
    // Firebase
    private var database: DatabaseReference?
    
    // Timers
    private var drivingConfirmationTimer: Timer?
    private var stoppedConfirmationTimer: Timer?
    private var analysisTimer: Timer?
    
    override init() {
        super.init()
        setupFirebase()
        setupLocationManager()
    }
    
    // MARK: - Setup Methods
    
    private func setupFirebase() {
        database = Database.database().reference()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // 5 meters
    }
    
    // MARK: - Public Methods
    
    func initialize(userId: String) -> Bool {
        guard !isInitialized else { return true }
        
        print("DrivingDetectionManager: Initializing for user: \(String(userId.prefix(8)))")
        
        currentUserId = userId
        
        // Request location permission
        locationManager.requestAlwaysAuthorization()
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Start motion updates if available
        startMotionUpdates()
        
        // Start analysis timer
        startAnalysisTimer()
        
        isInitialized = true
        print("DrivingDetectionManager: Initialized successfully")
        return true
    }
    
    func stop() {
        print("DrivingDetectionManager: Stopping")
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        
        // Stop motion updates
        stopMotionUpdates()
        
        // Cancel timers
        drivingConfirmationTimer?.invalidate()
        stoppedConfirmationTimer?.invalidate()
        analysisTimer?.invalidate()
        
        // End current driving session if active
        if isDriving {
            endDrivingSession()
        }
        
        isInitialized = false
        currentUserId = nil
    }
    
    // MARK: - Motion Detection
    
    private func startMotionUpdates() {
        // Start accelerometer updates
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1 // 10 Hz
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                self.handleAccelerometerData(data.acceleration)
            }
        }
        
        // Start gyroscope updates
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1 // 10 Hz
            motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                self.handleGyroscopeData(data.rotationRate)
            }
        }
    }
    
    private func stopMotionUpdates() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
    }
    
    private func handleAccelerometerData(_ acceleration: CMAcceleration) {
        // Calculate total acceleration magnitude (remove gravity)
        let totalAcceleration = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        ) - 1.0 // Remove gravity (1g)
        
        // Add to buffer
        accelerationBuffer.append(abs(totalAcceleration))
        if accelerationBuffer.count > bufferSize {
            accelerationBuffer.removeFirst()
        }
    }
    
    private func handleGyroscopeData(_ rotationRate: CMRotationRate) {
        // Calculate total rotation magnitude
        let totalRotation = sqrt(
            rotationRate.x * rotationRate.x +
            rotationRate.y * rotationRate.y +
            rotationRate.z * rotationRate.z
        )
        
        // Log significant rotation (indicating vehicle movement)
        if totalRotation > gyroscopeThreshold {
            print("DrivingDetectionManager: Significant rotation detected: \(totalRotation)")
        }
    }
    
    // MARK: - Analysis
    
    private func startAnalysisTimer() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.analyzeDrivingState()
        }
    }
    
    private func analyzeDrivingState() {
        guard !speedBuffer.isEmpty && !accelerationBuffer.isEmpty else { return }
        
        // Calculate average speed
        let avgSpeed = speedBuffer.reduce(0, +) / Double(speedBuffer.count)
        
        // Calculate average acceleration
        let avgAcceleration = accelerationBuffer.reduce(0, +) / Double(accelerationBuffer.count)
        
        print("DrivingDetectionManager: Analysis - Speed: \(avgSpeed) m/s, Acceleration: \(avgAcceleration) m/s²")
        
        // Determine driving state
        let shouldBeDriving = avgSpeed > drivingSpeedThreshold && avgAcceleration > accelerationThreshold
        let shouldBeStopped = avgSpeed < stoppedSpeedThreshold
        
        if !isDriving && shouldBeDriving {
            // Potentially started driving
            if drivingConfirmationTimer == nil {
                drivingConfirmationTimer = Timer.scheduledTimer(withTimeInterval: drivingConfirmationTime, repeats: false) { [weak self] _ in
                    self?.startDrivingSession()
                    self?.drivingConfirmationTimer = nil
                }
            }
        } else if isDriving && shouldBeStopped {
            // Potentially stopped driving
            if stoppedConfirmationTimer == nil {
                stoppedConfirmationTimer = Timer.scheduledTimer(withTimeInterval: stoppedConfirmationTime, repeats: false) { [weak self] _ in
                    self?.endDrivingSession()
                    self?.stoppedConfirmationTimer = nil
                }
            }
        } else {
            // Cancel pending timers if conditions changed
            drivingConfirmationTimer?.invalidate()
            drivingConfirmationTimer = nil
            stoppedConfirmationTimer?.invalidate()
            stoppedConfirmationTimer = nil
        }
    }
    
    // MARK: - Driving Session Management
    
    private func startDrivingSession() {
        guard !isDriving, let userId = currentUserId else { return }
        
        print("DrivingDetectionManager: Starting driving session")
        isDriving = true
        drivingStartTime = Date()
        totalDistance = 0.0
        maxSpeed = 0.0
        
        // Update Firebase
        let drivingData: [String: Any] = [
            "isDriving": true,
            "drivingStartTime": Date().timeIntervalSince1970 * 1000,
            "source": "ios_native_driving_detection"
        ]
        
        database?.child("users").child(userId).child("driving").updateChildValues(drivingData)
        
        // Notify Flutter layer
        notifyFlutter(event: "driving_started", data: drivingData)
    }
    
    private func endDrivingSession() {
        guard isDriving, let userId = currentUserId, let startTime = drivingStartTime else { return }
        
        print("DrivingDetectionManager: Ending driving session")
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Create driving session data
        let sessionData: [String: Any] = [
            "startTime": startTime.timeIntervalSince1970 * 1000,
            "endTime": endTime.timeIntervalSince1970 * 1000,
            "duration": duration * 1000, // Convert to milliseconds
            "distance": totalDistance,
            "maxSpeed": maxSpeed,
            "averageSpeed": totalDistance / duration,
            "source": "ios_native_driving_detection"
        ]
        
        // Save to Firebase
        database?.child("users").child(userId).child("drivingSessions").childByAutoId().setValue(sessionData)
        
        // Update current driving status
        let drivingData: [String: Any] = [
            "isDriving": false,
            "lastDrivingSession": sessionData
        ]
        
        database?.child("users").child(userId).child("driving").updateChildValues(drivingData)
        
        // Reset state
        isDriving = false
        drivingStartTime = nil
        totalDistance = 0.0
        maxSpeed = 0.0
        
        // Notify Flutter layer
        notifyFlutter(event: "driving_ended", data: sessionData)
    }
    
    // MARK: - Helper Methods
    
    private func notifyFlutter(event: String, data: [String: Any]) {
        // This would typically use a method channel to notify Flutter
        print("DrivingDetectionManager: Flutter notification: \(event) - \(data)")
    }
}

// MARK: - CLLocationManagerDelegate

@available(iOS 13.0, *)
extension DrivingDetectionManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isInitialized else { return }
        
        // Add location to buffer
        locationBuffer.append(location)
        if locationBuffer.count > bufferSize {
            locationBuffer.removeFirst()
        }
        
        // Calculate speed
        let speed = location.speed >= 0 ? location.speed : 0.0
        speedBuffer.append(speed)
        if speedBuffer.count > bufferSize {
            speedBuffer.removeFirst()
        }
        
        // Update max speed if driving
        if isDriving && speed > maxSpeed {
            maxSpeed = speed
        }
        
        // Calculate distance if driving
        if isDriving, let lastLoc = lastLocation {
            let distance = lastLoc.distance(from: location)
            totalDistance += distance
        }
        
        lastLocation = location
        
        // Trigger driving analysis
        analyzeDrivingState()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DrivingDetectionManager: Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("DrivingDetectionManager: Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if isInitialized {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("DrivingDetectionManager: Location permission denied")
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
}