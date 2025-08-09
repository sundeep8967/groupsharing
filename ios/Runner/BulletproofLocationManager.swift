import Foundation
import CoreLocation
import UIKit
import BackgroundTasks
import Firebase
import FirebaseDatabase
import FirebaseFirestore
import UserNotifications

// Configuration structure for bulletproof location tracking
struct BulletproofLocationConfig {
    let updateInterval: Int // milliseconds
    let distanceFilter: Double // meters
    let enableHighAccuracy: Bool
    let enablePersistentMode: Bool
}

@available(iOS 13.0, *)
class BulletproofLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = BulletproofLocationManager()
    
    // MARK: - Properties
    
    private var locationManager: CLLocationManager
    private var isTracking = false
    private var isInitialized = false
    private var currentUserId: String?
    private var config: BulletproofLocationConfig?
    
    // Background task management
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskTimer: Timer?
    
    // Health monitoring
    private var healthCheckTimer: Timer?
    private var lastLocationUpdate: Date?
    private var consecutiveFailures = 0
    private let maxConsecutiveFailures = 3
    private let healthCheckInterval: TimeInterval = 30.0
    
    // Firebase references
    private var realtimeDatabase: DatabaseReference?
    private var firestore: Firestore?
    
    // Location tracking state
    private var lastKnownLocation: CLLocation?
    private var firebaseRetryCount = 0
    private let maxFirebaseRetries = 5
    private var firebaseRetryTimer: Timer?
    
    // Background task identifier
    private let backgroundTaskIdentifier = "com.sundeep.groupsharing.bulletproof-location"
    
    // Notification helper
    private let notificationHelper = BulletproofNotificationHelper.shared
    
    // Permission helper
    private let permissionHelper = BulletproofPermissionHelper.shared
    
    // Method channel for Flutter communication
    private var methodChannel: FlutterMethodChannel?
    
    // MARK: - Initialization
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        
        print("🔥 BulletproofLocationManager: Initializing...")
        setupLocationManager()
        setupFirebase()
        setupBackgroundTasks()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
        print("🔥 BulletproofLocationManager: Method channel set for Flutter communication")
    }
    
    func initialize() -> Bool {
        guard !isInitialized else {
            print("🔥 BulletproofLocationManager: Already initialized")
            return true
        }
        
        print("🔥 BulletproofLocationManager: Starting initialization...")
        
        // Setup Firebase
        setupFirebase()
        
        // Setup background tasks
        setupBackgroundTasks()
        
        // Setup notifications
        setupNotifications()
        
        isInitialized = true
        print("🔥 BulletproofLocationManager: Initialization completed successfully")
        
        return true
    }
    
    func startTracking(userId: String, config: BulletproofLocationConfig) -> Bool {
        guard isInitialized else {
            print("❌ BulletproofLocationManager: Not initialized")
            return false
        }
        
        guard !isTracking else {
            print("🔥 BulletproofLocationManager: Already tracking for user: \(userId.prefix(8))")
            return true
        }
        
        print("🔥 BulletproofLocationManager: Starting bulletproof location tracking for user: \(userId.prefix(8))")
        
        self.currentUserId = userId
        self.config = config
        
        // Check and request permissions
        guard checkAndRequestPermissions() else {
            print("❌ BulletproofLocationManager: Permissions not granted")
            notifyFlutter(method: "onError", arguments: "Location permissions not granted")
            return false
        }
        
        // Configure location manager based on config
        configureLocationManager(config: config)
        
        // Start location tracking
        startLocationUpdates()
        
        // Start health monitoring
        startHealthMonitoring()
        
        // Start background task management
        startBackgroundTaskManagement()
        
        // Save tracking state
        saveTrackingState(isTracking: true, userId: userId)
        
        isTracking = true
        consecutiveFailures = 0
        firebaseRetryCount = 0
        
        print("🔥 BulletproofLocationManager: Bulletproof location tracking started successfully")
        
        // Show tracking notification
        notificationHelper.showLocationTrackingNotification()
        
        notifyFlutter(method: "onServiceStarted", arguments: nil)
        
        return true
    }
    
    func stopTracking() -> Bool {
        guard isTracking else {
            print("🔥 BulletproofLocationManager: Not currently tracking")
            return true
        }
        
        print("🔥 BulletproofLocationManager: Stopping bulletproof location tracking")
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
        locationManager.stopSignificantLocationChanges()
        
        // Stop health monitoring
        stopHealthMonitoring()
        
        // Stop background task management
        stopBackgroundTaskManagement()
        
        // Clear tracking state
        saveTrackingState(isTracking: false, userId: nil)
        
        isTracking = false
        currentUserId = nil
        config = nil
        consecutiveFailures = 0
        firebaseRetryCount = 0
        
        print("🔥 BulletproofLocationManager: Bulletproof location tracking stopped successfully")
        
        // Clear tracking notifications
        notificationHelper.clearLocationTrackingNotifications()
        
        notifyFlutter(method: "onServiceStopped", arguments: nil)
        
        return true
    }
    
    func isHealthy() -> Bool {
        guard isTracking else { return false }
        
        // Check if we've received location updates recently
        if let lastUpdate = lastLocationUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate > 120 { // 2 minutes
                return false
            }
        }
        
        // Check if we have too many consecutive failures
        if consecutiveFailures >= maxConsecutiveFailures {
            return false
        }
        
        // Check location authorization
        if locationManager.authorizationStatus != .authorizedAlways {
            return false
        }
        
        return true
    }
    
    func hasBackgroundLocationPermission() -> Bool {
        return permissionHelper.hasBackgroundLocationPermission()
    }
    
    func requestBackgroundLocationPermission() {
        permissionHelper.requestBackgroundLocationPermission { success in
            print("🔥 BulletproofLocationManager: Background location permission request result: \(success)")
        }
    }
    
    func initializePermissionMonitoring() {
        // Permission monitoring is handled automatically in iOS through delegate methods
        print("🔥 BulletproofLocationManager: Permission monitoring initialized")
    }
    
    func restoreTrackingState() -> Bool {
        let userDefaults = UserDefaults.standard
        let wasTracking = userDefaults.bool(forKey: "bulletproof_location_tracking")
        
        if wasTracking, let userId = userDefaults.string(forKey: "bulletproof_user_id") {
            print("🔥 BulletproofLocationManager: Restoring tracking state for user: \(userId.prefix(8))")
            
            // Create default config for restoration
            let defaultConfig = BulletproofLocationConfig(
                updateInterval: 15000,
                distanceFilter: 10.0,
                enableHighAccuracy: true,
                enablePersistentMode: true
            )
            
            return startTracking(userId: userId, config: defaultConfig)
        }
        
        return false
    }
    
    func handleAppWillTerminate() {
        print("🔥 BulletproofLocationManager: App will terminate - ensuring location tracking continues")
        
        if isTracking {
            // Ensure significant location changes are enabled for app termination
            locationManager.startSignificantLocationChanges()
            
            // Schedule background task to restart tracking
            scheduleBackgroundAppRefresh()
        }
    }
    
    // MARK: - Private Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        
        // Critical iOS settings for persistent background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        
        print("🔥 BulletproofLocationManager: Location manager configured with persistent settings")
    }
    
    private func setupFirebase() {
        realtimeDatabase = Database.database().reference()
        firestore = Firestore.firestore()
        print("🔥 BulletproofLocationManager: Firebase configured")
    }
    
    private func setupBackgroundTasks() {
        // Register background task for location updates
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundLocationTask(task as! BGAppRefreshTask)
        }
        
        print("🔥 BulletproofLocationManager: Background tasks registered")
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔥 BulletproofLocationManager: Notification permissions granted")
            } else {
                print("❌ BulletproofLocationManager: Notification permissions denied")
            }
        }
    }
    
    private func configureLocationManager(config: BulletproofLocationConfig) {
        // Configure accuracy
        locationManager.desiredAccuracy = config.enableHighAccuracy ? 
            kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters
        
        // Configure distance filter
        locationManager.distanceFilter = config.distanceFilter
        
        print("🔥 BulletproofLocationManager: Location manager configured with accuracy: \(locationManager.desiredAccuracy), filter: \(config.distanceFilter)")
    }
    
    private func checkAndRequestPermissions() -> Bool {
        // Check if all required permissions are granted
        if permissionHelper.hasAllRequiredPermissions() {
            return true
        }
        
        // Request missing permissions
        if !permissionHelper.hasLocationPermissions() {
            permissionHelper.requestLocationPermissions { success in
                print("🔥 BulletproofLocationManager: Location permission request result: \(success)")
            }
            return false
        }
        
        if !permissionHelper.hasBackgroundLocationPermission() {
            permissionHelper.requestBackgroundLocationPermission { success in
                print("🔥 BulletproofLocationManager: Background location permission request result: \(success)")
            }
            return false
        }
        
        if !permissionHelper.hasNotificationPermission() {
            permissionHelper.requestNotificationPermission { success in
                print("🔥 BulletproofLocationManager: Notification permission request result: \(success)")
            }
        }
        
        return permissionHelper.hasLocationPermissions() && permissionHelper.hasBackgroundLocationPermission()
    }
    
    // MARK: - Location Tracking
    
    private func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ BulletproofLocationManager: Location services not enabled")
            notifyFlutter(method: "onError", arguments: "Location services not enabled")
            return
        }
        
        // Start standard location updates
        locationManager.startUpdatingLocation()
        
        // Also start significant location changes for background reliability
        locationManager.startSignificantLocationChanges()
        
        print("🔥 BulletproofLocationManager: Location updates started")
    }
    
    private func processLocationUpdate(_ location: CLLocation) {
        lastKnownLocation = location
        lastLocationUpdate = Date()
        consecutiveFailures = 0
        firebaseRetryCount = 0
        
        print("🔥 BulletproofLocationManager: Location update - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude), Accuracy: \(location.horizontalAccuracy)m")
        
        // Update Firebase
        updateFirebaseLocation(location)
        
        // Notify Flutter
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000,
            "provider": "ios_core_location"
        ]
        
        notifyFlutter(method: "onLocationUpdate", arguments: locationData)
    }
    
    private func updateFirebaseLocation(_ location: CLLocation) {
        guard let userId = currentUserId else { return }
        
        let locationData: [String: Any] = [
            "userId": userId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": ServerValue.timestamp(),
            "accuracy": location.horizontalAccuracy,
            "source": "bulletproof_ios_service"
        ]
        
        // Update Realtime Database
        realtimeDatabase?.child("locations").child(userId).setValue(locationData) { [weak self] error, _ in
            if let error = error {
                print("❌ BulletproofLocationManager: Failed to update Realtime Database: \(error)")
                self?.handleFirebaseError(location)
            } else {
                print("🔥 BulletproofLocationManager: Realtime Database updated successfully")
            }
        }
        
        // Update Firestore
        firestore?.collection("user_locations").document(userId).setData(locationData, merge: true) { [weak self] error in
            if let error = error {
                print("❌ BulletproofLocationManager: Failed to update Firestore: \(error)")
                self?.handleFirebaseError(location)
            } else {
                print("🔥 BulletproofLocationManager: Firestore updated successfully")
            }
        }
    }
    
    private func handleFirebaseError(_ location: CLLocation) {
        firebaseRetryCount += 1
        
        if firebaseRetryCount <= maxFirebaseRetries {
            print("🔥 BulletproofLocationManager: Retrying Firebase update (attempt \(firebaseRetryCount))")
            
            firebaseRetryTimer?.invalidate()
            firebaseRetryTimer = Timer.scheduledTimer(withTimeInterval: Double(firebaseRetryCount * 5), repeats: false) { [weak self] _ in
                self?.updateFirebaseLocation(location)
            }
        } else {
            print("❌ BulletproofLocationManager: Max Firebase retries reached")
            notifyFlutter(method: "onError", arguments: "Firebase updates failing persistently")
        }
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        
        print("🔥 BulletproofLocationManager: Health monitoring started")
    }
    
    private func stopHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        
        print("🔥 BulletproofLocationManager: Health monitoring stopped")
    }
    
    private func performHealthCheck() {
        print("🔥 BulletproofLocationManager: Performing health check...")
        
        // Check if we've received location updates recently
        if let lastUpdate = lastLocationUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate > 120 { // 2 minutes
                print("⚠️ BulletproofLocationManager: No location updates for \(Int(timeSinceLastUpdate)) seconds")
                handleServiceFailure(reason: "No recent location updates")
                return
            }
        }
        
        // Check location authorization
        if locationManager.authorizationStatus != .authorizedAlways {
            print("⚠️ BulletproofLocationManager: Location authorization changed")
            handlePermissionFailure()
            return
        }
        
        // Check if location services are enabled
        if !CLLocationManager.locationServicesEnabled() {
            print("⚠️ BulletproofLocationManager: Location services disabled")
            notifyFlutter(method: "onError", arguments: "Location services disabled")
            return
        }
        
        print("✅ BulletproofLocationManager: Health check passed")
    }
    
    private func handleServiceFailure(reason: String) {
        print("❌ BulletproofLocationManager: Service failure detected: \(reason)")
        consecutiveFailures += 1
        
        if consecutiveFailures >= maxConsecutiveFailures {
            print("🔄 BulletproofLocationManager: Attempting to restart location tracking")
            
            // Stop current tracking
            locationManager.stopUpdatingLocation()
            locationManager.stopSignificantLocationChanges()
            
            // Wait a moment and restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startLocationUpdates()
                self?.consecutiveFailures = 0
            }
        }
        
        notifyFlutter(method: "onError", arguments: reason)
    }
    
    private func handlePermissionFailure() {
        print("❌ BulletproofLocationManager: Permission failure detected")
        
        // Show permission revoked notification
        notificationHelper.showPermissionRevokedNotification()
        
        notifyFlutter(method: "onPermissionRevoked", arguments: nil)
        notifyFlutter(method: "onError", arguments: "Location permissions revoked")
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTaskManagement() {
        // Schedule background app refresh
        scheduleBackgroundAppRefresh()
        
        // Start background task timer
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.scheduleBackgroundAppRefresh()
        }
        
        print("🔥 BulletproofLocationManager: Background task management started")
    }
    
    private func stopBackgroundTaskManagement() {
        backgroundTaskTimer?.invalidate()
        backgroundTaskTimer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        print("🔥 BulletproofLocationManager: Background task management stopped")
    }
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🔥 BulletproofLocationManager: Background app refresh scheduled")
        } catch {
            print("❌ BulletproofLocationManager: Failed to schedule background app refresh: \(error)")
        }
    }
    
    private func handleBackgroundLocationTask(_ task: BGAppRefreshTask) {
        print("🔥 BulletproofLocationManager: Handling background location task")
        
        // Schedule the next background refresh
        scheduleBackgroundAppRefresh()
        
        // Ensure location tracking is still active
        if isTracking {
            startLocationUpdates()
        }
        
        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ BulletproofLocationManager: Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Complete the task after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("✅ BulletproofLocationManager: Background task completed")
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - State Persistence
    
    private func saveTrackingState(isTracking: Bool, userId: String?) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(isTracking, forKey: "bulletproof_location_tracking")
        
        if let userId = userId {
            userDefaults.set(userId, forKey: "bulletproof_user_id")
        } else {
            userDefaults.removeObject(forKey: "bulletproof_user_id")
        }
        
        userDefaults.synchronize()
        print("🔥 BulletproofLocationManager: Tracking state saved")
    }
    
    // MARK: - Flutter Communication
    
    private func notifyFlutter(method: String, arguments: Any?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let channel = self.methodChannel else {
                print("⚠️ BulletproofLocationManager: Method channel not available for \(method)")
                return
            }
            
            channel.invokeMethod(method, arguments: arguments) { result in
                if let error = result as? FlutterError {
                    print("❌ BulletproofLocationManager: Flutter method \(method) failed: \(error)")
                } else {
                    print("✅ BulletproofLocationManager: Flutter method \(method) called successfully")
                }
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge > 5.0 { // Ignore locations older than 5 seconds
            return
        }
        
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 {
            return // Ignore inaccurate locations
        }
        
        processLocationUpdate(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ BulletproofLocationManager: Location manager failed with error: \(error)")
        consecutiveFailures += 1
        
        if consecutiveFailures >= maxConsecutiveFailures {
            handleServiceFailure(reason: "Location manager failed: \(error.localizedDescription)")
        }
        
        notifyFlutter(method: "onError", arguments: "Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔥 BulletproofLocationManager: Authorization status changed to: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("📍 BulletproofLocationManager: Location permission not determined")
            
        case .denied, .restricted:
            print("❌ BulletproofLocationManager: Location permission denied or restricted")
            handlePermissionFailure()
            
        case .authorizedWhenInUse:
            print("📍 BulletproofLocationManager: Location permission granted for when in use")
            // Request always authorization for background tracking
            locationManager.requestAlwaysAuthorization()
            
        case .authorizedAlways:
            print("✅ BulletproofLocationManager: Location permission granted for always")
            if isTracking {
                startLocationUpdates()
            }
            
        @unknown default:
            print("❓ BulletproofLocationManager: Unknown authorization status")
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("⏸️ BulletproofLocationManager: Location updates paused")
        
        // Force resume if we're supposed to be tracking
        if isTracking {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("▶️ BulletproofLocationManager: Location updates resumed")
    }
}