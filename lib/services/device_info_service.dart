import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'dart:io';

class DeviceInfoService {
  static final Battery _battery = Battery();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final FirebaseFirestore _firestore = FirebaseService.firestore;

  static Future<void> sendDeviceAndBatteryInfo(String userId) async {
    // Battery info
    final batteryLevel = await _battery.batteryLevel;
    final batteryState = await _battery.batteryState;
    final isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;

    // Device info
    Map<String, dynamic> deviceData = {};
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceData = {
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'version': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceData = {
        'model': iosInfo.utsname.machine,
        'name': iosInfo.name,
        'systemVersion': iosInfo.systemVersion,
        'isPhysicalDevice': iosInfo.isPhysicalDevice,
      };
    }

    // Send to Firestore
    await _firestore.collection('users').doc(userId).collection('device_status').doc('latest').set({
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'batteryState': batteryState.toString(),
      'timestamp': FieldValue.serverTimestamp(),
      ...deviceData,
    }, SetOptions(merge: true));
  }
} 