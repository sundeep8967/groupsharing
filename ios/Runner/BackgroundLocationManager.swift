import Foundation
import CoreLocation
import UIKit
import BackgroundTasks
import Firebase
import FirebaseDatabase
import UserNotifications

@available(iOS 13.0, *)
class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = BackgroundLocationManager()
    
    private var locationManager: CLLocationManager
    private var isTracking = false
    private var currentUserId: String?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var heartbeatTimer: Timer?
    
    // Configuration
    private let distanceFilter: CLLocationDistance = 10.0
    private let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    private let heartbeatInterval: TimeInterval = 30.0
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.sundeep.groupsharing.background-location"
    
    // Firebase reference
    private var database: DatabaseReference?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        
        setupLocationManager()
        setupFirebase()
        setupBackgroundTasks()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        
        // Critical for iOS background location - Life360 style
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Additional settings for persistent location like Google Maps
        locationManager.showsBackgroundLocationIndicator = true
        
        print("iOS Background Location Manager initialized with persistent settings")
    }
    
    private func setupFirebase() {
        database = Database.database().reference()
        print("Firebase database reference initialized")
    }
    
    private func setupBackgroundTasks() {
        // Register multiple background tasks for reliability like Life360
        let identifiers = [
            "com.sundeep.groupsharing.background-location",
            "com.sundeep.groupsharing.location-sync", 
            "com.sundeep.groupsharing.heartbeat"
        ]
        
        for identifier in identifiers {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                if let appRefreshTask = task as? BGAppRefreshTask {
                    self.handleBackgroundLocationTask(task: appRefreshTask)
                } else if let processingTask = task as? BGProcessingTask {
                    self.handleBackgroundProcessingTask(task: processingTask)
                }
            }
        }
        print("Multiple background tasks registered for reliability")
    }
    
    // MARK: - Public Methods
    
    func startTracking(userId: String) -> Bool {
        guard !isTracking else {
            print("Location tracking already active")
            return true
        }
        
        currentUserId = userId
        
        // Check and request authorization
        let authStatus = locationManager.authorizationStatus
        if authStatus != .authorizedAlways {
            print("Requesting always authorization for background location")
            locationManager.requestAlwaysAuthorization()
            return false // Will retry when authorization is granted
        }
        
        // Start location services - Life360 style with multiple methods
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start background task
        startBackgroundTask()
        
        // Start heartbeat
        startHeartbeat()
        
        // Schedule background tasks for when app is killed
        scheduleAllBackgroundTasks()
        
        // Save state
        saveTrackingState(enabled: true, userId: userId)
        
        isTracking = true
        print("iOS background location tracking started for user: \(userId.prefix(8)) with persistent mode")
        return true
    }
    
    func stopTracking() -> Bool {
        guard isTracking else { return true }
        
        // Stop location services
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop background task
        endBackgroundTask()
        
        // Stop heartbeat
        stopHeartbeat()
        
        // Clear user data
        if let userId = currentUserId {
            clearUserLocationData(userId: userId)
        }
        
        // Save state
        saveTrackingState(enabled: false, userId: nil)
        
        isTracking = false
        currentUserId = nil
        print("iOS background location tracking stopped")
        return true
    }
    
    func isCurrentlyTracking() -> Bool {
        return isTracking
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
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
    
    private func handleBackgroundLocationTask(task: BGAppRefreshTask) {
        // Schedule next background task
        scheduleBackgroundLocationTask()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform location update
        if isTracking {
            // Request a fresh location
            locationManager.requestLocation()
        }
        
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleBackgroundLocationTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func scheduleAllBackgroundTasks() {
        // Schedule multiple background tasks for maximum reliability
        scheduleBackgroundLocationTask()
        scheduleLocationSyncTask()
        scheduleHeartbeatTask()
    }
    
    private func scheduleLocationSyncTask() {
        let request = BGProcessingTaskRequest(identifier: "com.sundeep.groupsharing.location-sync")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func scheduleHeartbeatTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.sundeep.groupsharing.heartbeat")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60) // 2 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundProcessingTask(task: BGProcessingTask) {
        // Schedule next task
        scheduleLocationSyncTask()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform comprehensive location sync
        if isTracking {
            performLocationSync { success in
                task.setTaskCompleted(success: success)
            }
        } else {
            task.setTaskCompleted(success: true)
        }
    }
    
    private func performLocationSync(completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId else {
            completion(false)
            return
        }
        
        // Get current location and sync to Firebase
        locationManager.requestLocation()
        
        // Also send heartbeat
        sendHeartbeat()
        
        // Check if we need to restart location services
        if !isTracking {
            _ = startTracking(userId: userId)
        }
        
        completion(true)
    }
    
    // MARK: - Heartbeat Management
    
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
        guard let userId = currentUserId, let database = database else { return }
        
        let heartbeatData: [String: Any] = [
            "lastHeartbeat": ServerValue.timestamp(),
            "appUninstalled": false,
            "serviceActive": true,
            "platform": "ios"
        ]
        
        database.child("users").child(userId).updateChildValues(heartbeatData) { error, _ in
            if let error = error {
                print("Failed to send heartbeat: \(error.localizedDescription)")
            } else {
                print("Heartbeat sent successfully")
            }
        }
    }
    
    // MARK: - Firebase Updates
    
    private func updateLocationInFirebase(location: CLLocation) {
        guard let userId = currentUserId, let database = database else { return }
        
        let locationData: [String: Any] = [
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
            "isSharing": true,
            "source": "ios_native_service",
            "speed": location.speed >= 0 ? location.speed : 0,
            "bearing": location.course >= 0 ? location.course : 0
        ]
        
        // Update location in realtime database
        database.child("locations").child(userId).setValue(locationData) { error, _ in
            if let error = error {
                print("Failed to update location in Firebase: \(error.localizedDescription)")
            } else {
                print("Location updated in Firebase: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                // Check proximity to friends after successful update
                self.checkProximityToFriends(userLocation: location)
                // Monitor friends' locations
                self.monitorFriendsLocations()
            }
        }
        
        // Update user status with comprehensive data
        let userUpdate: [String: Any] = [
            "lastLocationUpdate": ServerValue.timestamp(),
            "locationSharingEnabled": true,
            "appUninstalled": false,
            "serviceActive": true,
            "lastSeen": ServerValue.timestamp(),
            "platform": "ios",
            "deviceInfo": getDeviceInfo()
        ]
        
        database.child("users").child(userId).updateChildValues(userUpdate)
    }
    
    private func clearUserLocationData(userId: String) {
        guard let database = database else { return }
        
        // Remove from locations
        database.child("locations").child(userId).removeValue()
        
        // Update user status
        let userUpdate: [String: Any] = [
            "locationSharingEnabled": false,
            "serviceActive": false,
            "lastSeen": ServerValue.timestamp()
        ]
        
        database.child("users").child(userId).updateChildValues(userUpdate)
        print("Cleared location data for user: \(userId.prefix(8))")
    }
    
    // MARK: - State Persistence
    
    private func saveTrackingState(enabled: Bool, userId: String?) {
        UserDefaults.standard.set(enabled, forKey: "location_sharing_enabled")
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: "user_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "user_id")
        }
        UserDefaults.standard.synchronize()
        print("Saved tracking state: enabled=\(enabled), userId=\(userId?.prefix(8) ?? "nil")")
    }
    
    func restoreTrackingState() -> Bool {
        let enabled = UserDefaults.standard.bool(forKey: "location_sharing_enabled")
        let userId = UserDefaults.standard.string(forKey: "user_id")
        
        if enabled, let userId = userId {
            print("Restoring location tracking for user: \(userId.prefix(8))")
            return startTracking(userId: userId)
        }
        
        return false
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isTracking else { return }
        
        // Filter out old or inaccurate locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge > 5.0 || location.horizontalAccuracy > 100 {
            return
        }
        
        print("New iOS location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        updateLocationInFirebase(location: location)
        
        // Start background task for processing
        startBackgroundTask()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            print("Always authorization granted - can start background location")
            if let userId = currentUserId, !isTracking {
                _ = startTracking(userId: userId)
            }
        case .authorizedWhenInUse:
            print("Only when-in-use authorization - requesting always authorization")
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("Location authorization denied or restricted")
            if isTracking {
                _ = stopTracking()
            }
        case .notDetermined:
            print("Location authorization not determined")
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    // MARK: - App Lifecycle
    
    func handleAppDidEnterBackground() {
        if isTracking {
            startBackgroundTask()
            scheduleBackgroundLocationTask()
            print("App entered background - background location active")
        }
    }
    
    func handleAppWillEnterForeground() {
        if isTracking {
            endBackgroundTask()
            print("App entering foreground - continuing location tracking")
        }
    }
    
    func handleAppWillTerminate() {
        if isTracking {
            // iOS will continue location updates for apps with background location capability
            print("App terminating - iOS will continue background location")
        }
    }
    
    // MARK: - Core Native Features
    
    private func checkProximityToFriends(userLocation: CLLocation) {
        guard let userId = currentUserId, let database = database else { return }
        
        database.child("locations").observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let friendId = childSnapshot.key as String?,
                      friendId != userId else { continue }
                
                if let friendData = childSnapshot.value as? [String: Any],
                   let friendLat = friendData["lat"] as? Double,
                   let friendLng = friendData["lng"] as? Double,
                   let isSharing = friendData["isSharing"] as? Bool,
                   isSharing {
                    
                    let friendLocation = CLLocation(latitude: friendLat, longitude: friendLng)
                    let distance = userLocation.distance(from: friendLocation)
                    
                    print("Distance to friend \(String(friendId.prefix(8))): \(distance)m")
                    
                    // Notify if within 500m (proximity threshold)
                    if distance <= 500 {
                        self.sendProximityNotification(friendId: friendId, distance: distance)
                    }
                }
            }
        }
    }
    
    private func monitorFriendsLocations() {
        guard let userId = currentUserId, let database = database else { return }
        
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            let currentTime = Date().timeIntervalSince1970 * 1000
            
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let friendId = childSnapshot.key as String?,
                      friendId != userId else { continue }
                
                if let userData = childSnapshot.value as? [String: Any],
                   let lastHeartbeat = userData["lastHeartbeat"] as? Double,
                   let locationSharingEnabled = userData["locationSharingEnabled"] as? Bool,
                   let appUninstalled = userData["appUninstalled"] as? Bool,
                   locationSharingEnabled && !appUninstalled {
                    
                    // Check if friend's heartbeat is stale (more than 2 minutes)
                    if (currentTime - lastHeartbeat) > 120000 {
                        print("Friend \(String(friendId.prefix(8))) appears to be offline (stale heartbeat)")
                        self.markFriendAsOffline(friendId: friendId)
                    }
                }
            }
        }
    }
    
    private func sendProximityNotification(friendId: String, distance: Double) {
        guard let database = database else { return }
        
        // Get friend's name from Firebase
        database.child("users").child(friendId).observeSingleEvent(of: .value) { snapshot in
            let friendName = (snapshot.value as? [String: Any])?["displayName"] as? String ?? "Friend"
            
            // Create proximity notification
            let title = "Friend Nearby"
            let message = "\(friendName) is \(Int(distance))m away"
            
            self.showLocalNotification(title: title, message: message, identifier: "proximity_\(friendId)")
        }
    }
    
    private func markFriendAsOffline(friendId: String) {
        guard let userId = currentUserId, let database = database else { return }
        
        // Mark friend as having stale heartbeat
        let offlineUpdate: [String: Any] = [
            "appUninstalled": true,
            "locationSharingEnabled": false,
            "lastSeen": ServerValue.timestamp(),
            "uninstallReason": "stale_heartbeat_detected_by_\(String(userId.prefix(8)))"
        ]
        
        database.child("users").child(friendId).updateChildValues(offlineUpdate)
        
        // Remove from locations
        database.child("locations").child(friendId).removeValue()
        
        print("Marked friend as offline: \(String(friendId.prefix(8)))")
    }
    
    private func showLocalNotification(title: String, message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            } else {
                print("Notification sent: \(title) - \(message)")
            }
        }
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "identifierForVendor": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "lastUpdate": Int64(Date().timeIntervalSince1970 * 1000)
        ]
    }
    
    // Enhanced heartbeat with comprehensive status
    private func sendHeartbeat() {
        guard let userId = currentUserId, let database = database else { return }
        
        let heartbeatData: [String: Any] = [
            "lastHeartbeat": Int64(Date().timeIntervalSince1970 * 1000),
            "appUninstalled": false,
            "serviceActive": true,
            "platform": "ios",
            "lastSeen": ServerValue.timestamp(),
            "deviceInfo": getDeviceInfo()
        ]
        
        database.child("users").child(userId).updateChildValues(heartbeatData) { error, _ in
            if let error = error {
                print("Failed to send enhanced heartbeat: \(error.localizedDescription)")
            } else {
                print("Enhanced heartbeat sent with device info")
            }
        }
    }
}