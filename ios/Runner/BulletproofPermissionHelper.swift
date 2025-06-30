import Foundation
import CoreLocation
import UserNotifications

@available(iOS 13.0, *)
class BulletproofPermissionHelper: NSObject {
    static let shared = BulletproofPermissionHelper()
    
    private var locationManager: CLLocationManager
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
    }
    
    // MARK: - Permission Checking
    
    func hasAllRequiredPermissions() -> Bool {
        return hasLocationPermissions() && 
               hasBackgroundLocationPermission() && 
               hasNotificationPermission()
    }
    
    func hasLocationPermissions() -> Bool {
        return CLLocationManager.locationServicesEnabled() &&
               (locationManager.authorizationStatus == .authorizedWhenInUse ||
                locationManager.authorizationStatus == .authorizedAlways)
    }
    
    func hasBackgroundLocationPermission() -> Bool {
        return locationManager.authorizationStatus == .authorizedAlways
    }
    
    func hasNotificationPermission() -> Bool {
        var hasPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            hasPermission = settings.authorizationStatus == .authorized
            semaphore.signal()
        }
        
        semaphore.wait()
        return hasPermission
    }
    
    func isLocationServiceEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    // MARK: - Permission Requests
    
    func requestLocationPermissions(completion: @escaping (Bool) -> Void) {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            completion(false) // Will be handled in delegate
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            completion(false) // Will be handled in delegate
        case .authorizedAlways:
            completion(true)
        default:
            completion(false)
        }
    }
    
    func requestBackgroundLocationPermission(completion: @escaping (Bool) -> Void) {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
            completion(false) // Will be handled in delegate
        } else if locationManager.authorizationStatus == .authorizedAlways {
            completion(true)
        } else {
            completion(false)
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Permission Status
    
    func getPermissionStatus() -> [String: Bool] {
        return [
            "location": hasLocationPermissions(),
            "backgroundLocation": hasBackgroundLocationPermission(),
            "notification": hasNotificationPermission(),
            "locationService": isLocationServiceEnabled()
        ]
    }
    
    func getMissingPermissions() -> [String] {
        var missingPermissions: [String] = []
        
        if !hasLocationPermissions() {
            missingPermissions.append("Location permissions")
        }
        
        if !hasBackgroundLocationPermission() {
            missingPermissions.append("Background location permission")
        }
        
        if !hasNotificationPermission() {
            missingPermissions.append("Notification permission")
        }
        
        if !isLocationServiceEnabled() {
            missingPermissions.append("Location services")
        }
        
        return missingPermissions
    }
    
    func getPermissionInstructions() -> [String] {
        var instructions: [String] = []
        
        if !hasLocationPermissions() {
            instructions.append("Grant location permissions when prompted")
        }
        
        if !hasBackgroundLocationPermission() {
            instructions.append("Allow location access 'Always' in app settings")
        }
        
        if !hasNotificationPermission() {
            instructions.append("Enable notifications for this app")
        }
        
        if !isLocationServiceEnabled() {
            instructions.append("Enable Location Services in device settings")
        }
        
        return instructions
    }
    
    // MARK: - Settings Navigation
    
    func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    func openLocationSettings() {
        // iOS doesn't allow direct navigation to location settings
        // Users need to go through app settings
        openAppSettings()
    }
}