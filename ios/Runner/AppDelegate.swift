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
  private var bulletproofLocationManager: BulletproofLocationManager?
  
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
      bulletproofLocationManager = BulletproofLocationManager.shared
      
      // Restore tracking state if app was terminated
      _ = backgroundLocationManager?.restoreTrackingState()
      _ = bulletproofLocationManager?.restoreTrackingState()
    }
    
    // Set up method channels
    setupLocationChannels()
    setupNativeServiceChannels()
    setupBulletproofLocationChannels()
    
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
    
    // Setup battery optimization channel (iOS compatibility)
    let batteryChannel = FlutterMethodChannel(
      name: "com.sundeep.groupsharing/battery_optimization",
      binaryMessenger: controller.binaryMessenger
    )
    
    batteryChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleBatteryOptimizationCall(call, result: result)
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
      
    case "initialize":
      result(true)
      
    case "startPersistentService":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let success = locationManager.startTracking(userId: userId)
      result(success)
      
    case "stopPersistentService":
      let success = locationManager.stopTracking()
      result(success)
      
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
      bulletproofLocationManager?.handleAppWillTerminate()
    }
  }
  
  // MARK: - Bulletproof Location Service Channels
  
  private func setupBulletproofLocationChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    // Setup bulletproof location service channel
    let bulletproofChannel = FlutterMethodChannel(
      name: "bulletproof_location_service",
      binaryMessenger: controller.binaryMessenger
    )
    
    bulletproofChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleBulletproofLocationCall(call, result: result)
    }
    
    // Setup bulletproof permissions channel
    let permissionsChannel = FlutterMethodChannel(
      name: "bulletproof_permissions",
      binaryMessenger: controller.binaryMessenger
    )
    
    permissionsChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleBulletproofPermissionsCall(call, result: result)
    }
    
    // Setup bulletproof battery channel (iOS doesn't have battery optimization like Android)
    let batteryChannel = FlutterMethodChannel(
      name: "bulletproof_battery",
      binaryMessenger: controller.binaryMessenger
    )
    
    batteryChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleBulletproofBatteryCall(call, result: result)
    }
  }
  
  private func handleBulletproofLocationCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let bulletproofManager = bulletproofLocationManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    // Set up method channel communication for callbacks
    if let controller = window?.rootViewController as? FlutterViewController {
      let bulletproofChannel = FlutterMethodChannel(
        name: "bulletproof_location_service",
        binaryMessenger: controller.binaryMessenger
      )
      bulletproofManager.setMethodChannel(bulletproofChannel)
    }
    
    switch call.method {
    case "initialize":
      let success = bulletproofManager.initialize()
      result(success)
      
    case "initializeIOS":
      let success = bulletproofManager.initialize()
      result(success)
      
    case "startBulletproofService":
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "User ID required", details: nil))
        return
      }
      
      let updateInterval = args["updateInterval"] as? Int ?? 15000
      let distanceFilter = args["distanceFilter"] as? Double ?? 10.0
      let enableHighAccuracy = args["enableHighAccuracy"] as? Bool ?? true
      let enablePersistentMode = args["enablePersistentMode"] as? Bool ?? true
      
      let config = BulletproofLocationConfig(
        updateInterval: updateInterval,
        distanceFilter: distanceFilter,
        enableHighAccuracy: enableHighAccuracy,
        enablePersistentMode: enablePersistentMode
      )
      
      let success = bulletproofManager.startTracking(userId: userId, config: config)
      result(success)
      
    case "stopBulletproofService":
      let success = bulletproofManager.stopTracking()
      result(success)
      
    case "checkServiceHealth":
      result(bulletproofManager.isHealthy())
      
    case "setupDeviceOptimizations":
      // iOS doesn't need device-specific optimizations like Android
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleBulletproofPermissionsCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *),
          let bulletproofManager = bulletproofLocationManager else {
      result(FlutterError(code: "UNAVAILABLE", message: "iOS 13.0+ required", details: nil))
      return
    }
    
    switch call.method {
    case "initializePermissionMonitoring":
      bulletproofManager.initializePermissionMonitoring()
      result(true)
      
    case "checkBackgroundLocationPermission":
      result(bulletproofManager.hasBackgroundLocationPermission())
      
    case "requestBackgroundLocationPermission":
      bulletproofManager.requestBackgroundLocationPermission()
      result(true)
      
    case "checkExactAlarmPermission":
      // iOS doesn't have exact alarm permissions like Android
      result(true)
      
    case "requestExactAlarmPermission":
      // iOS doesn't need exact alarm permissions
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleBatteryOptimizationCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // iOS doesn't have battery optimization settings like Android
    switch call.method {
    case "isBatteryOptimizationDisabled":
      result(true) // iOS doesn't have battery optimization
      
    case "requestDisableBatteryOptimization":
      result(nil) // No action needed on iOS
      
    case "checkDeviceSpecificOptimizations":
      result(true) // No device-specific optimizations needed on iOS
      
    case "requestAutoStartPermission":
      result(nil) // No auto-start permission needed on iOS
      
    case "requestBackgroundAppPermission":
      result(nil) // No background app permission needed on iOS
      
    case "getComprehensiveOptimizationStatus":
      let status: [String: Any] = [
        "batteryOptimizationDisabled": true,
        "autoStartEnabled": true,
        "backgroundAppEnabled": true,
        "deviceManufacturer": "iOS"
      ]
      result(status)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func handleBulletproofBatteryCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // iOS doesn't have battery optimization settings like Android
    switch call.method {
    case "initializeBatteryOptimizations":
      result(true)
      
    case "requestBatteryOptimizationExemption":
      result(true)
      
    case "requestAutoStartPermission":
      result(true)
      
    case "requestBackgroundAppPermission":
      result(true)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
