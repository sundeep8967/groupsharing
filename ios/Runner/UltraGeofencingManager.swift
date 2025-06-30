import Foundation
import CoreLocation
import UserNotifications
import UIKit

/**
 * Ultra-Active Geofencing Manager for iOS
 * This service provides military-grade location tracking that survives:
 * - App termination
 * - Phone restart
 * - Background app refresh limitations
 * - Low power mode
 */
@objc class UltraGeofencingManager: NSObject {
    
    static let shared = UltraGeofencingManager()
    
    private let locationManager = CLLocationManager()
    private var methodChannel: FlutterMethodChannel?
    private var currentUserId: String?
    private var isUltraActive = false
    private var activeGeofences: [String: CLCircularRegion] = [:]
    private var lastKnownLocation: CLLocation?
    
    // Configuration
    private let geofenceRadius: CLLocationDistance = 5.0 // 5 meters
    private let locationAccuracy = kCLLocationAccuracyBestForNavigation
    private let distanceFilter: CLLocationDistance = 5.0 // 5 meters
    
    override init() {
        super.init()
        setupLocationManager()
        setupNotifications()
    }
    
    func setMethodChannel(_ channel: FlutterMethodChannel) {
        self.methodChannel = channel
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = locationAccuracy
        locationManager.distanceFilter = distanceFilter
        
        // Request always authorization for background tracking
        locationManager.requestAlwaysAuthorization()
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("UltraGeofencing: Notification permission error: \(error)")
            }
        }
    }
    
    func startUltraActiveTracking(userId: String, ultraActive: Bool) {
        print("UltraGeofencing: Starting ultra-active tracking for user: \(String(userId.prefix(8)))")
        
        currentUserId = userId
        isUltraActive = ultraActive
        
        // Start location updates
        startLocationUpdates()
        
        // Start significant location change monitoring (survives app termination)
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start region monitoring for geofences
        startRegionMonitoring()
        
        // Schedule background tasks
        scheduleBackgroundTasks()
    }
    
    private func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            sendError("Location services not enabled")
            return
        }
        
        guard locationManager.authorizationStatus == .authorizedAlways else {
            sendError("Always location permission required")
            return
        }
        
        locationManager.startUpdatingLocation()
        
        // Also start significant location changes for background
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    private func startRegionMonitoring() {
        // Region monitoring will be started when geofences are added
    }
    
    private func scheduleBackgroundTasks() {
        // Schedule background app refresh
        if #available(iOS 13.0, *) {
            let identifier = "com.example.groupsharing.ultra-geofencing"
            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
            
            try? BGTaskScheduler.shared.submit(request)
        }
    }
    
    func addGeofence(id: String, lat: Double, lng: Double, radius: Double, name: String) {
        print("UltraGeofencing: Adding geofence: \(name) at \(lat), \(lng) (\(radius)m)")
        
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        activeGeofences[id] = region
        
        // Start monitoring the region
        locationManager.startMonitoring(for: region)
        
        // Request state for immediate check
        locationManager.requestState(for: region)
    }
    
    func removeGeofence(id: String) {
        if let region = activeGeofences[id] {
            locationManager.stopMonitoring(for: region)
            activeGeofences.removeValue(forKey: id)
            print("UltraGeofencing: Removed geofence: \(id)")
        }
    }
    
    func stopTracking() {
        print("UltraGeofencing: Stopping ultra-active tracking")
        
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop monitoring all geofences
        for region in activeGeofences.values {
            locationManager.stopMonitoring(for: region)
        }
        activeGeofences.removeAll()
        
        currentUserId = nil
        isUltraActive = false
        lastKnownLocation = nil
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // Check if location changed by 5+ meters
        if let lastLocation = lastKnownLocation {
            let distance = location.distance(from: lastLocation)
            if distance < geofenceRadius {
                return // Location hasn't changed significantly
            }
        }
        
        lastKnownLocation = location
        
        // Process geofences manually for ultra-precision
        processGeofences(location)
        
        // Send location update to Flutter
        sendLocationUpdate(location)
        
        // Send local notification if app is in background
        if UIApplication.shared.applicationState != .active {
            sendLocationNotification(location)
        }
    }
    
    private func processGeofences(_ location: CLLocation) {
        for (geofenceId, region) in activeGeofences {
            let geofenceLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distance = location.distance(from: geofenceLocation)
            let isInside = distance <= region.radius
            
            // Send geofence event to Flutter
            sendGeofenceEvent(geofenceId: geofenceId, entered: isInside)
        }
    }
    
    private func sendLocationUpdate(_ location: CLLocation) {
        let locationData: [String: Any] = [
            "lat": location.coordinate.latitude,
            "lng": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)
        ]
        
        methodChannel?.invokeMethod("onLocationUpdate", arguments: locationData)
    }
    
    private func sendGeofenceEvent(geofenceId: String, entered: Bool) {
        let eventData: [String: Any] = [
            "geofenceId": geofenceId,
            "entered": entered,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        methodChannel?.invokeMethod("onGeofenceEvent", arguments: eventData)
    }
    
    private func sendError(_ message: String) {
        methodChannel?.invokeMethod("onError", arguments: ["error": message])
    }
    
    private func sendLocationNotification(_ location: CLLocation) {
        let content = UNMutableNotificationContent()
        content.title = "Ultra Geofencing Active"
        content.body = "Location: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))"
        content.sound = nil // Silent notification
        
        let request = UNNotificationRequest(
            identifier: "ultra-geofencing-location",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func checkServiceHealth() -> Bool {
        return locationManager.authorizationStatus == .authorizedAlways &&
               CLLocationManager.locationServicesEnabled()
    }
}

// MARK: - CLLocationManagerDelegate
extension UltraGeofencingManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocationUpdate(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            print("UltraGeofencing: Entered region: \(region.identifier)")
            sendGeofenceEvent(geofenceId: region.identifier, entered: true)
            
            // Send local notification
            let content = UNMutableNotificationContent()
            content.title = "Geofence Entered"
            content.body = "Entered: \(region.identifier)"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "geofence-enter-\(region.identifier)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            print("UltraGeofencing: Exited region: \(region.identifier)")
            sendGeofenceEvent(geofenceId: region.identifier, entered: false)
            
            // Send local notification
            let content = UNMutableNotificationContent()
            content.title = "Geofence Exited"
            content.body = "Exited: \(region.identifier)"
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: "geofence-exit-\(region.identifier)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let isInside = state == .inside
        print("UltraGeofencing: Region state determined: \(region.identifier) - \(isInside ? "INSIDE" : "OUTSIDE")")
        sendGeofenceEvent(geofenceId: region.identifier, entered: isInside)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("UltraGeofencing: Authorization status changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            print("UltraGeofencing: Always authorization granted")
            if let userId = currentUserId {
                startLocationUpdates()
            }
        case .authorizedWhenInUse:
            print("UltraGeofencing: When in use authorization granted - requesting always")
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            sendError("Location permission denied")
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        @unknown default:
            sendError("Unknown location authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("UltraGeofencing: Location manager error: \(error)")
        sendError("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("UltraGeofencing: Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error)")
        sendError("Geofence monitoring error: \(error.localizedDescription)")
    }
}

// MARK: - Background Task Handling
@available(iOS 13.0, *)
extension UltraGeofencingManager {
    
    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        print("UltraGeofencing: Handling background task")
        
        // Schedule next background task
        scheduleBackgroundTasks()
        
        // Perform location update
        if let location = locationManager.location {
            handleLocationUpdate(location)
        }
        
        // Complete the task
        task.setTaskCompleted(success: true)
    }
}

// Import required for background tasks
import BackgroundTasks