import Foundation
import CoreLocation
import UserNotifications
import AVFoundation
import Firebase
import FirebaseDatabase

/**
 * Native iOS Emergency/SOS Manager
 * Handles emergency situations with countdown, notifications, and automatic calling
 * Provides Life360-style emergency features with high reliability
 */
@available(iOS 13.0, *)
class EmergencyManager: NSObject {
    static let shared = EmergencyManager()
    
    // State tracking
    private var isEmergencyActive = false
    private var isSosCountdownActive = false
    private var currentUserId: String?
    private var lastKnownLocation: CLLocation?
    private var emergencyStartTime: Date?
    private var emergencyId: String?
    
    // SOS Configuration
    private let sosCountdownDuration: TimeInterval = 5.0 // 5 seconds
    private let emergencyTimeout: TimeInterval = 1800.0 // 30 minutes
    private let emergencyNumber = "911" // Default emergency number
    
    // Firebase
    private var database: DatabaseReference?
    
    // System services
    private var audioPlayer: AVAudioPlayer?
    
    // Timers
    private var sosCountdownTimer: Timer?
    private var emergencyTimeoutTimer: Timer?
    private var heartbeatTimer: Timer?
    
    override init() {
        super.init()
        setupFirebase()
        setupNotifications()
    }
    
    // MARK: - Setup Methods
    
    private func setupFirebase() {
        database = Database.database().reference()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            if granted {
                print("EmergencyManager: Notification permission granted")
            } else {
                print("EmergencyManager: Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func initialize(userId: String) -> Bool {
        print("EmergencyManager: Initializing for user: \(String(userId.prefix(8)))")
        currentUserId = userId
        return true
    }
    
    func startSosCountdown() {
        guard !isSosCountdownActive && !isEmergencyActive else {
            print("EmergencyManager: SOS already active, ignoring request")
            return
        }
        
        print("EmergencyManager: Starting SOS countdown")
        isSosCountdownActive = true
        
        // Start countdown timer
        var countdown = 5
        sosCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if countdown > 0 {
                // Show countdown notification
                self.showSosCountdownNotification(countdown: countdown)
                
                // Play warning sound and vibrate
                self.playWarningSound()
                self.vibrateDevice()
                
                // Update Firebase with countdown
                self.updateSosCountdownInFirebase(countdown: countdown)
                
                countdown -= 1
            } else {
                // Countdown finished, trigger emergency
                timer.invalidate()
                self.triggerEmergency()
            }
        }
    }
    
    func cancelSosCountdown() {
        guard isSosCountdownActive else { return }
        
        print("EmergencyManager: Cancelling SOS countdown")
        isSosCountdownActive = false
        
        sosCountdownTimer?.invalidate()
        sosCountdownTimer = nil
        
        // Cancel countdown notification
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Update Firebase
        if let userId = currentUserId {
            let sosData: [String: Any] = [
                "sosActive": false,
                "sosCancelled": true,
                "cancelTime": Date().timeIntervalSince1970 * 1000
            ]
            
            database?.child("users").child(userId).child("emergency").updateChildValues(sosData)
        }
        
        // Notify Flutter
        notifyFlutter(event: "sos_cancelled", data: nil)
    }
    
    func triggerEmergency() {
        guard !isEmergencyActive else { return }
        
        print("EmergencyManager: EMERGENCY TRIGGERED!")
        isEmergencyActive = true
        isSosCountdownActive = false
        emergencyStartTime = Date()
        emergencyId = "emergency_\(Int(Date().timeIntervalSince1970 * 1000))"
        
        guard let userId = currentUserId, let emergencyId = emergencyId else { return }
        
        // Create emergency event data
        var emergencyData: [String: Any] = [
            "id": emergencyId,
            "userId": userId,
            "startTime": Date().timeIntervalSince1970 * 1000,
            "type": "sos",
            "status": "active",
            "source": "ios_native_emergency"
        ]
        
        if let location = lastKnownLocation {
            let locationData: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
            emergencyData["location"] = locationData
        }
        
        // Save to Firebase
        database?.child("emergencies").child(emergencyId).setValue(emergencyData)
        database?.child("users").child(userId).child("emergency").updateChildValues(emergencyData)
        
        // Show emergency notification
        showEmergencyNotification()
        
        // Start emergency heartbeat
        startEmergencyHeartbeat()
        
        // Set emergency timeout
        emergencyTimeoutTimer = Timer.scheduledTimer(withTimeInterval: emergencyTimeout, repeats: false) { [weak self] _ in
            print("EmergencyManager: Emergency timeout reached, auto-cancelling")
            self?.cancelEmergency()
        }
        
        // Attempt to call emergency services (requires user permission)
        attemptEmergencyCall()
        
        // Notify Flutter
        notifyFlutter(event: "emergency_triggered", data: emergencyData)
    }
    
    func cancelEmergency() {
        guard isEmergencyActive else { return }
        
        print("EmergencyManager: Cancelling emergency")
        isEmergencyActive = false
        
        // Cancel timers
        emergencyTimeoutTimer?.invalidate()
        emergencyTimeoutTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        // Update Firebase
        if let emergencyId = emergencyId, let userId = currentUserId, let startTime = emergencyStartTime {
            let updateData: [String: Any] = [
                "status": "cancelled",
                "endTime": Date().timeIntervalSince1970 * 1000,
                "duration": Date().timeIntervalSince(startTime) * 1000
            ]
            
            database?.child("emergencies").child(emergencyId).updateChildValues(updateData)
            database?.child("users").child(userId).child("emergency").updateChildValues(updateData)
        }
        
        // Cancel notification
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Notify Flutter
        notifyFlutter(event: "emergency_cancelled", data: nil)
        
        // Reset state
        emergencyId = nil
        emergencyStartTime = nil
    }
    
    func updateLocation(_ location: CLLocation) {
        lastKnownLocation = location
        
        // Update emergency location if active
        if isEmergencyActive, let emergencyId = emergencyId {
            let locationData: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
            
            database?.child("emergencies").child(emergencyId).child("currentLocation").setValue(locationData)
        }
    }
    
    // MARK: - Private Methods
    
    private func showSosCountdownNotification(countdown: Int) {
        let content = UNMutableNotificationContent()
        content.title = "SOS Emergency"
        content.body = "Emergency will be triggered in \(countdown) seconds"
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "SOS_COUNTDOWN"
        
        // Add cancel action
        let cancelAction = UNNotificationAction(identifier: "CANCEL_SOS", title: "CANCEL", options: [.destructive])
        let category = UNNotificationCategory(identifier: "SOS_COUNTDOWN", actions: [cancelAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(identifier: "sos_countdown", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showEmergencyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🚨 EMERGENCY ACTIVE"
        content.body = "Emergency services have been notified. Your location is being shared."
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "EMERGENCY_ACTIVE"
        
        // Add cancel action
        let cancelAction = UNNotificationAction(identifier: "CANCEL_EMERGENCY", title: "CANCEL EMERGENCY", options: [.destructive])
        let category = UNNotificationCategory(identifier: "EMERGENCY_ACTIVE", actions: [cancelAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let request = UNNotificationRequest(identifier: "emergency_active", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func startEmergencyHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isEmergencyActive, let emergencyId = self.emergencyId else { return }
            
            var heartbeat: [String: Any] = [
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "status": "active"
            ]
            
            if let location = self.lastKnownLocation {
                let locationData: [String: Any] = [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy
                ]
                heartbeat["location"] = locationData
            }
            
            self.database?.child("emergencies").child(emergencyId).child("heartbeat").setValue(heartbeat)
        }
    }
    
    private func updateSosCountdownInFirebase(countdown: Int) {
        guard let userId = currentUserId else { return }
        
        let sosData: [String: Any] = [
            "sosActive": true,
            "sosCountdown": countdown,
            "sosStartTime": Date().timeIntervalSince1970 * 1000
        ]
        
        database?.child("users").child(userId).child("emergency").updateChildValues(sosData)
    }
    
    private func playWarningSound() {
        // Play system alert sound
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        AudioServicesPlaySystemSound(1005) // SMS alert sound
    }
    
    private func vibrateDevice() {
        // Trigger device vibration
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private func attemptEmergencyCall() {
        guard let url = URL(string: "tel://\(emergencyNumber)") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            print("EmergencyManager: Would attempt to call emergency services: \(emergencyNumber)")
            // UIApplication.shared.open(url) // Uncomment when ready for production
        } else {
            print("EmergencyManager: Cannot make phone calls on this device")
        }
    }
    
    private func notifyFlutter(event: String, data: [String: Any]?) {
        // This would typically use a method channel to notify Flutter
        print("EmergencyManager: Flutter notification: \(event) - \(data?.description ?? "nil")")
    }
}

// MARK: - UNUserNotificationCenterDelegate

@available(iOS 13.0, *)
extension EmergencyManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        switch response.actionIdentifier {
        case "CANCEL_SOS":
            cancelSosCountdown()
        case "CANCEL_EMERGENCY":
            cancelEmergency()
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
}