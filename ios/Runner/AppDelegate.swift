import Flutter
import UIKit
import CoreLocation
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backgroundLocationManager: BackgroundLocationManager?
  private var drivingDetectionManager: DrivingDetectionManager?
  private var emergencyManager: EmergencyManager?
  private var geofenceManager: GeofenceManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize Firebase
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize native managers
    if #available(iOS 13.0, *) {
      backgroundLocationManager = BackgroundLocationManager.shared
      drivingDetectionManager = DrivingDetectionManager.shared
      emergencyManager = EmergencyManager.shared
      geofenceManager = GeofenceManager.shared
      
      // Restore tracking state if app was terminated
      _ = backgroundLocationManager?.restoreTrackingState()
    }
    
    // Set up method channels
    setupLocationChannels()
    setupNativeServiceChannels()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupLocationChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    // Setup persistent location service channel
    let persistentChannel = FlutterMethodChannel(
      name: "persistent_location_service",
      binaryMessenger: controller.binaryMessenger
    )
    
    persistentChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handlePersistentLocationCall(call, result: result)
    }
    
    // Setup background location channel (for compatibility)
    let backgroundChannel = FlutterMethodChannel(
      name: "background_location",
      binaryMessenger: controller.binaryMessenger
    )
    
    backgroundChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleBackgroundLocationCall(call, result: result)
    }
  }
  
  private func handlePersistentLocationCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let locationManager = backgroundLocationManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "startBackgroundLocationService":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = locationManager.startTracking(userId: userId)
      result(success)
      
    case "stopBackgroundLocationService":
      let success = locationManager.stopTracking()
      result(success)
      
    case "isServiceHealthy":
      result(locationManager.isCurrentlyTracking())
      
    case "requestBackgroundLocationPermission":
      // iOS handles this automatically when starting location
      result(true)
      
    case "registerBackgroundLocationHandler":
      // Background handlers are automatically registered in iOS
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleBackgroundLocationCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let locationManager = backgroundLocationManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "start":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = locationManager.startTracking(userId: userId)
      result(success)
      
    case "stop":
      let success = locationManager.stopTracking()
      result(success)
      
    case "isServiceRunning":
      result(locationManager.isCurrentlyTracking())
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func setupNativeServiceChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    // Setup driving detection channel
    let drivingChannel = FlutterMethodChannel(
      name: "native_driving_detection",
      binaryMessenger: controller.binaryMessenger
    )
    
    drivingChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleDrivingDetectionCall(call, result: result)
    }
    
    // Setup emergency service channel
    let emergencyChannel = FlutterMethodChannel(
      name: "native_emergency_service",
      binaryMessenger: controller.binaryMessenger
    )
    
    emergencyChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleEmergencyServiceCall(call, result: result)
    }
    
    // Setup geofence service channel
    let geofenceChannel = FlutterMethodChannel(
      name: "native_geofence_service",
      binaryMessenger: controller.binaryMessenger
    )
    
    geofenceChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleGeofenceServiceCall(call, result: result)
    }
  }
  
  private func handleDrivingDetectionCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let drivingManager = drivingDetectionManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = drivingManager.initialize(userId: userId)
      result(success)
      
    case "stop":
      drivingManager.stop()
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleEmergencyServiceCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let emergencyManager = emergencyManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = emergencyManager.initialize(userId: userId)
      result(success)
      
    case "startSos":
      emergencyManager.startSosCountdown()
      result(true)
      
    case "cancelSos":
      emergencyManager.cancelSosCountdown()
      result(true)
      
    case "triggerEmergency":
      emergencyManager.triggerEmergency()
      result(true)
      
    case "cancelEmergency":
      emergencyManager.cancelEmergency()
      result(true)
      
    case "updateLocation":
      guard let args = call.arguments as? [String: Any],
            let latitude = args["latitude"] as? Double,
            let longitude = args["longitude"] as? Double else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Location coordinates required", details: nil))
        return
      }
      
      let location = CLLocation(latitude: latitude, longitude: longitude)
      emergencyManager.updateLocation(location)
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleGeofenceServiceCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let geofenceManager = geofenceManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = geofenceManager.initialize(userId: userId)
      result(success)
      
    case "addGeofence":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String,
            let latitude = args["latitude"] as? Double,
            let longitude = args["longitude"] as? Double,
            let radius = args["radius"] as? Double,
            let name = args["name"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Geofence parameters required", details: nil))
        return
      }
      
      geofenceManager.addGeofence(id: id, latitude: latitude, longitude: longitude, radius: radius, name: name)
      result(true)
      
    case "removeGeofence":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Geofence ID required", details: nil))
        return
      }
      
      geofenceManager.removeGeofence(id: id)
      result(true)
      
    case "clearAll":
      geofenceManager.clearAllGeofences()
      result(true)
      
    case "stop":
      geofenceManager.stop()
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - App Lifecycle
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    
    if #available(iOS 13.0, *) {
      backgroundLocationManager?.handleAppDidEnterBackground()
    }
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    
    if #available(iOS 13.0, *) {
      backgroundLocationManager?.handleAppWillEnterForeground()
    }
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    super.applicationWillTerminate(application)
    
    if #available(iOS 13.0, *) {
      backgroundLocationManager?.handleAppWillTerminate()
    }
  }
}
