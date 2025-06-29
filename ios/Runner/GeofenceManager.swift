import Foundation
import CoreLocation
import UserNotifications
import Firebase
import FirebaseDatabase

/**
 * Native iOS Geofence Manager
 * Handles location-based triggers and smart place detection
 * Provides Life360-style geofencing with high accuracy and reliability
 */
@available(iOS 13.0, *)
class GeofenceManager: NSObject {
    static let shared = GeofenceManager()
    
    // Location manager
    private let locationManager = CLLocationManager()
    
    // State tracking
    private var isInitialized = false
    private var currentUserId: String?
    private var activeGeofences: [CLRegion] = []
    
    // Geofence configuration
    private let defaultGeofenceRadius: CLLocationDistance = 100.0 // 100 meters
    private let maxGeofences = 20 // iOS limit is 20 geofences per app
    
    // Firebase
    private var database: DatabaseReference?
    
    override init() {
        super.init()
        setupFirebase()
        setupLocationManager()
        setupNotifications()
    }
    
    // MARK: - Setup Methods
    
    private func setupFirebase() {
        database = Database.database().reference()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("GeofenceManager: Notification permission granted")
            } else {
                print("GeofenceManager: Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func initialize(userId: String) -> Bool {
        guard !isInitialized else { return true }
        
        print("GeofenceManager: Initializing for user: \(String(userId.prefix(8)))")
        
        currentUserId = userId
        
        // Request location permission
        locationManager.requestAlwaysAuthorization()
        
        // Add default smart places
        addSmartPlaces()
        
        isInitialized = true
        print("GeofenceManager: Initialized successfully")
        return true
    }
    
    func addGeofence(id: String, latitude: Double, longitude: Double, radius: Double, name: String) {
        guard isInitialized else {
            print("GeofenceManager: Not initialized")
            return
        }
        
        // Check if we've reached the iOS limit
        if activeGeofences.count >= maxGeofences {
            print("GeofenceManager: Maximum geofences reached (\(maxGeofences))")
            return
        }
        
        print("GeofenceManager: Adding geofence: \(id) at \(latitude), \(longitude)")
        
        // Create geofence region
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Start monitoring
        locationManager.startMonitoring(for: region)
        activeGeofences.append(region)
        
        // Save to Firebase
        saveGeofenceToFirebase(id: id, latitude: latitude, longitude: longitude, radius: radius, name: name)
        
        print("GeofenceManager: Geofence added successfully: \(id)")
    }
    
    func removeGeofence(id: String) {
        print("GeofenceManager: Removing geofence: \(id)")
        
        // Find and remove the region
        if let region = activeGeofences.first(where: { $0.identifier == id }) {
            locationManager.stopMonitoring(for: region)
            activeGeofences.removeAll { $0.identifier == id }
            
            // Remove from Firebase
            removeGeofenceFromFirebase(id: id)
            
            print("GeofenceManager: Geofence removed successfully: \(id)")
        } else {
            print("GeofenceManager: Geofence not found: \(id)")
        }
    }
    
    func clearAllGeofences() {
        print("GeofenceManager: Clearing all geofences")
        
        for region in activeGeofences {
            locationManager.stopMonitoring(for: region)
        }
        
        activeGeofences.removeAll()
        print("GeofenceManager: All geofences cleared")
    }
    
    func stop() {
        print("GeofenceManager: Stopping")
        
        clearAllGeofences()
        isInitialized = false
        currentUserId = nil
    }
    
    // MARK: - Private Methods
    
    private func addSmartPlaces() {
        // Add common smart places (these would typically be user-configured)
        addPredefinedPlace(id: "home", name: "Home", latitude: 0.0, longitude: 0.0, radius: 150.0)
        addPredefinedPlace(id: "work", name: "Work", latitude: 0.0, longitude: 0.0, radius: 100.0)
        addPredefinedPlace(id: "school", name: "School", latitude: 0.0, longitude: 0.0, radius: 100.0)
        
        print("GeofenceManager: Smart places setup initiated")
    }
    
    private func addPredefinedPlace(id: String, name: String, latitude: Double, longitude: Double, radius: Double) {
        guard let userId = currentUserId else { return }
        
        // In a real implementation, these coordinates would come from user settings
        let placeData: [String: Any] = [
            "id": id,
            "name": name,
            "latitude": latitude,
            "longitude": longitude,
            "radius": radius,
            "type": "smart_place",
            "created": Date().timeIntervalSince1970 * 1000,
            "source": "ios_native_geofence"
        ]
        
        // Save to Firebase for Flutter to read and configure
        database?.child("users").child(userId).child("smartPlaces").child(id).setValue(placeData)
    }
    
    private func saveGeofenceToFirebase(id: String, latitude: Double, longitude: Double, radius: Double, name: String) {
        guard let userId = currentUserId else { return }
        
        let geofenceData: [String: Any] = [
            "id": id,
            "name": name,
            "latitude": latitude,
            "longitude": longitude,
            "radius": radius,
            "active": true,
            "created": Date().timeIntervalSince1970 * 1000,
            "source": "ios_native_geofence"
        ]
        
        database?.child("users").child(userId).child("geofences").child(id).setValue(geofenceData)
    }
    
    private func removeGeofenceFromFirebase(id: String) {
        guard let userId = currentUserId else { return }
        
        database?.child("users").child(userId).child("geofences").child(id).removeValue()
    }
    
    private func handleGeofenceTransition(region: CLRegion, transitionType: String, location: CLLocation?) {
        guard let userId = currentUserId else { return }
        
        print("GeofenceManager: Geofence transition: \(region.identifier) - \(transitionType)")
        
        // Create transition event
        var eventData: [String: Any] = [
            "geofenceId": region.identifier,
            "transitionType": transitionType,
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "source": "ios_native_geofence"
        ]
        
        if let location = location {
            let locationData: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy
            ]
            eventData["location"] = locationData
        }
        
        // Save event to Firebase
        database?.child("users").child(userId).child("geofenceEvents").childByAutoId().setValue(eventData)
        
        // Update current place status
        let statusUpdate: [String: Any] = [
            "currentPlace": transitionType == "entered" ? region.identifier : NSNull(),
            "lastTransition": transitionType,
            "lastTransitionTime": Date().timeIntervalSince1970 * 1000
        ]
        
        database?.child("users").child(userId).child("placeStatus").updateChildValues(statusUpdate)
        
        // Show notification for place transitions
        showPlaceNotification(placeId: region.identifier, transition: transitionType)
    }
    
    private func showPlaceNotification(placeId: String, transition: String) {
        let content = UNMutableNotificationContent()
        content.title = "Location Update"
        content.body = "You have \(transition) \(placeId)"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "geofence_\(placeId)_\(transition)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CLLocationManagerDelegate

@available(iOS 13.0, *)
extension GeofenceManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("GeofenceManager: Entered region: \(region.identifier)")
        handleGeofenceTransition(region: region, transitionType: "entered", location: manager.location)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("GeofenceManager: Exited region: \(region.identifier)")
        handleGeofenceTransition(region: region, transitionType: "exited", location: manager.location)
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("GeofenceManager: Started monitoring region: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("GeofenceManager: Monitoring failed for region: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("GeofenceManager: Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            print("GeofenceManager: Always authorization granted")
        case .authorizedWhenInUse:
            print("GeofenceManager: When in use authorization granted")
            // Request always authorization for geofencing
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("GeofenceManager: Location permission denied")
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
}