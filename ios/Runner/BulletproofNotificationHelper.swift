import Foundation
import UserNotifications

@available(iOS 13.0, *)
class BulletproofNotificationHelper: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BulletproofNotificationHelper()
    
    override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Notification Management
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ BulletproofNotificationHelper: Failed to request notification permission: \(error)")
                    completion(false)
                } else {
                    print("🔥 BulletproofNotificationHelper: Notification permission granted: \(granted)")
                    completion(granted)
                }
            }
        }
    }
    
    func showLocationTrackingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Location Sharing Active"
        content.body = "GroupSharing is sharing your location with family members"
        content.sound = nil // Silent notification
        content.badge = nil
        
        let request = UNNotificationRequest(
            identifier: "bulletproof_location_tracking",
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ BulletproofNotificationHelper: Failed to show tracking notification: \(error)")
            } else {
                print("🔥 BulletproofNotificationHelper: Location tracking notification shown")
            }
        }
    }
    
    func showLocationUpdateNotification(latitude: Double, longitude: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Location Updated"
        content.body = "Your location has been shared with family members"
        content.sound = nil // Silent notification
        content.badge = nil
        
        // Add location data to user info
        content.userInfo = [
            "latitude": latitude,
            "longitude": longitude,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let request = UNNotificationRequest(
            identifier: "bulletproof_location_update_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ BulletproofNotificationHelper: Failed to show location update notification: \(error)")
            }
        }
    }
    
    func showServiceErrorNotification(error: String) {
        let content = UNMutableNotificationContent()
        content.title = "Location Service Issue"
        content.body = "There was an issue with location tracking: \(error)"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "bulletproof_service_error_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ BulletproofNotificationHelper: Failed to show error notification: \(error)")
            } else {
                print("🔥 BulletproofNotificationHelper: Service error notification shown")
            }
        }
    }
    
    func showPermissionRevokedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Location Permission Required"
        content.body = "Please enable location permissions to continue sharing your location with family"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "bulletproof_permission_revoked",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ BulletproofNotificationHelper: Failed to show permission notification: \(error)")
            } else {
                print("🔥 BulletproofNotificationHelper: Permission revoked notification shown")
            }
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔥 BulletproofNotificationHelper: All notifications cleared")
    }
    
    func clearLocationTrackingNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "bulletproof_location_tracking"
        ])
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
            "bulletproof_location_tracking"
        ])
        
        print("🔥 BulletproofNotificationHelper: Location tracking notifications cleared")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        
        switch identifier {
        case "bulletproof_permission_revoked":
            // Open app settings when user taps permission notification
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
}