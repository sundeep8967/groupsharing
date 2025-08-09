import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProtectionService {
  static const MethodChannel _batteryChannel = MethodChannel('com.sundeep.groupsharing/battery_optimization');

  static const _ackKeyAutostart = 'protection_ack_oem_autostart';
  static const _ackKeyForceStop = 'protection_ack_force_stop';

  // Battery optimization status
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _batteryChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
    } catch (_) {}
  }

  // OEM autostart helpers
  static Future<void> requestOemAutostart() async {
    if (!Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('requestAutoStartPermission');
    } catch (_) {}
  }

  static Future<void> openBackgroundAppPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _batteryChannel.invokeMethod('requestBackgroundAppPermission');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getOptimizationStatus() async {
    if (!Platform.isAndroid) return {
      'batteryOptimizationDisabled': true,
      'autoStartEnabled': true,
      'backgroundAppEnabled': true,
      'deviceManufacturer': 'iOS',
    };
    try {
      final result = await _batteryChannel.invokeMethod<Map>('getComprehensiveOptimizationStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (_) {
      return {
        'batteryOptimizationDisabled': false,
        'autoStartEnabled': false,
        'backgroundAppEnabled': false,
        'deviceManufacturer': 'unknown',
      };
    }
  }

  // Persist acknowledgements
  static Future<void> setAckAutostart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ackKeyAutostart, value);
  }

  static Future<bool> getAckAutostart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ackKeyAutostart) ?? false;
    }

  static Future<void> setAckForceStop(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ackKeyForceStop, value);
  }

  static Future<bool> getAckForceStop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ackKeyForceStop) ?? false;
  }

  // OEM guidance links
  static Future<void> openOemGuide() async {
    const url = 'https://dontkillmyapp.com/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
