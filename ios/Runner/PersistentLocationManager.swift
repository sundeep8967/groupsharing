import Foundation
import CoreLocation
import UIKit
import BackgroundTasks
import Firebase
import FirebaseDatabase

@available(iOS 13.0, *)
class PersistentLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = PersistentLocationManager()
    
    private var locationManager: CLLocationManager
    private var isTracking = false
    private var currentUserId: String?
    private var lastLocationTime: Date?
    private var heartbeatTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Configuration
    private let locationUpdateInterval: TimeInterval = 15.0
    private let heartbeatInterval: TimeInterval = 30.0
    private let distanceFilter: CLLocationDistance = 10.0
    private let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.sundeep.groupsharing.location-update"
    
    // Firebase references
    private var database: DatabaseReference?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        
        setupLocationManager()
        setupFirebase()
        setupBackgroundTasks()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        
        // Critical for iOS background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request always authorization for background location
        locationManager.requestAlwaysAuthorization()
    }
    
    private func setupFirebase() {
        database = Database.database().reference()
    }
    
    private func setupBackgroundTasks() {
        // Register background task for iOS 13+
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.handleBackgroundLocationUpdate(task: task as! BGAppRefreshTask)
            }
        }
        locationManager.distanceFilter = distanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Register background task
        registerBackgroundTask()
    }
    
    // MARK: - Public Methods
    
    func startTracking(userId: String) -> Bool {
        guard !isTracking else { return true }
        
        currentUserId = userId
        
        // Check authorization status
        let authStatus = locationManager.authorizationStatus
        guard authStatus == .authorizedAlways else {
            print("Background location not authorized")
            return false
        }
        
        // Start location updates
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start heartbeat
        startHeartbeat()
        
        isTracking = true
        lastLocationTime = Date()
        
        print("iOS persistent location tracking started for user: \(userId)")
        return true
    }
    
    func stopTracking() -> Bool {
        guard isTracking else { return true }
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop heartbeat
        stopHeartbeat()
        
        // End background task
        endBackgroundTask()
        
        // Clear user location data
        if let userId = currentUserId {
            clearUserLocationData(userId: userId)
        }
        
        isTracking = false
        currentUserId = nil
        lastLocationTime = nil
        
        print("iOS persistent location tracking stopped")
        return true
    }
    
    func requestLocationPermissions() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func isLocationAuthorized() -> Bool {
        return locationManager.authorizationStatus == .authorizedAlways
    }
    
    // MARK: - Private Methods
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundLocationUpdate(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundLocationUpdate(task: BGAppRefreshTask) {
        print("Handling background location update")
        
        // Schedule next background task
        scheduleBackgroundTask()
        
        // Start background task to ensure we have time to complete
        beginBackgroundTask()
        
        // Get current location
        if isTracking {
            locationManager.requestLocation()
        }
        
        // Mark task as completed
        task.setTaskCompleted(success: true)
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LocationUpdate") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { _ in
            self.sendHeartbeat()
        }
        
        // Send initial heartbeat
        sendHeartbeat()
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        guard let userId = currentUserId else { return }
        
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let heartbeatData: [String: Any] = [
            "lastHeartbeat": timestamp,
            "appUninstalled": false,
            "platform": "ios",
            "lastSeen": [".sv": "timestamp"]
        ]
        
        updateFirebaseData(userId: userId, path: "users/\(userId)", data: heartbeatData)
    }
    
    private func processLocationUpdate(_ location: CLLocation) {
        guard let userId = currentUserId, isTracking else { return }
        
        // Filter out old or inaccurate locations
        guard isLocationValid(location) else { return }
        
        lastLocationTime = Date()
        
        // Update Firebase with location
        let locationData: [String: Any] = [
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude,
            "isSharing": true,
            "updatedAt": [".sv": "timestamp"],
            "source": "ios_persistent",
            "accuracy": location.horizontalAccuracy
        ]
        
        updateFirebaseData(userId: userId, path: "locations/\(userId)", data: locationData)
        
        // Also update user document
        let userLocationData: [String: Any] = [
            "location": [
                "lat": location.coordinate.latitude,
                "lng": location.coordinate.longitude,
                "updatedAt": [".sv": "timestamp"]
            ],
            "lastOnline": [".sv": "timestamp"]
        ]
        
        updateFirestoreData(userId: userId, data: userLocationData)
        
        print("iOS location processed: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    private func isLocationValid(_ location: CLLocation) -> Bool {
        // Check accuracy
        if location.horizontalAccuracy > 100 || location.horizontalAccuracy < 0 {
            return false
        }
        
        // Check age
        let locationAge = abs(location.timestamp.timeIntervalSinceNow)
        if locationAge > 60 { // Older than 1 minute
            return false
        }
        
        return true
    }
    
    private func updateFirebaseData(userId: String, path: String, data: [String: Any]) {
        // This would typically use Firebase SDK to update Realtime Database
        // For now, we'll use a REST API call
        
        let firebaseUrl = "https://group-sharing-9d119-default-rtdb.firebaseio.com/\(path).json"
        
        guard let url = URL(string: firebaseUrl) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Firebase update error: \(error)")
                } else {
                    print("Firebase updated successfully")
                }
            }.resume()
        } catch {
            print("JSON serialization error: \(error)")
        }
    }
    
    private func updateFirestoreData(userId: String, data: [String: Any]) {
        // This would typically use Firebase SDK to update Firestore
        // Implementation would depend on your Firebase setup
        print("Firestore update for user: \(userId)")
    }
    
    private func clearUserLocationData(userId: String) {
        // Remove from Realtime Database
        updateFirebaseData(userId: userId, path: "locations/\(userId)", data: [:])
        
        // Update status
        let statusData: [String: Any] = [
            "locationSharingEnabled": false,
            "lastSeen": [".sv": "timestamp"]
        ]
        
        updateFirebaseData(userId: userId, path: "users/\(userId)", data: statusData)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        beginBackgroundTask()
        processLocationUpdate(location)
        
        // End background task after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.endBackgroundTask()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
        
        // Try to restart location updates after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isTracking {
                manager.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            if isTracking {
                manager.startUpdatingLocation()
                manager.startMonitoringSignificantLocationChanges()
            }
        case .denied, .restricted:
            stopTracking()
        default:
            break
        }
    }
}

// MARK: - App Lifecycle Handling

extension PersistentLocationManager {
    func handleAppDidEnterBackground() {
        if isTracking {
            scheduleBackgroundTask()
            beginBackgroundTask()
        }
    }
    
    func handleAppWillEnterForeground() {
        endBackgroundTask()
        
        if isTracking {
            // Restart location updates when app comes to foreground
            locationManager.startUpdatingLocation()
        }
    }
    
    func handleAppWillTerminate() {
        if isTracking {
            // Try to send final status update
            if let userId = currentUserId {
                let terminationData: [String: Any] = [
                    "locationSharingEnabled": false,
                    "appTerminated": true,
                    "lastSeen": [".sv": "timestamp"]
                ]
                
                updateFirebaseData(userId: userId, path: "users/\(userId)", data: terminationData)
            }
        }
    }
}