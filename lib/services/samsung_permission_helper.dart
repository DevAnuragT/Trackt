import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SamsungPermissionHelper extends GetxService {
  final RxBool isSamsungDevice = false.obs;
  final RxBool hasOptimizedSettings = false.obs;

  @override
  void onInit() {
    super.onInit();
    _detectDeviceType();
  }

  Future<void> _detectDeviceType() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();
        
        isSamsungDevice.value = manufacturer.contains('samsung');
        
        if (isSamsungDevice.value) {
          print('📱 Samsung device detected: ${androidInfo.model}');
          print('📱 Android version: ${androidInfo.version.release}');
          print('📱 SDK level: ${androidInfo.version.sdkInt}');
          
          // Optionally, you could show a dialog or nothing at all here.
          // _showSamsungInstructions(); // Snackbar removed as per design request
        }
      }
    } catch (e) {
      print('Device detection failed: $e');
    }
  }

  /// Get Samsung-specific location settings recommendations
  Map<String, String> getSamsungLocationSettings() {
    return {
      'location_mode': 'High accuracy (GPS + WiFi + Mobile networks)',
      'battery_optimization': 'Disabled for this app',
      'background_activity': 'Allowed',
      'sleep_settings': 'Never sleep',
      'location_permission': 'Allow all the time',
    };
  }

  /// Show detailed Samsung optimization guide
  void showDetailedOptimizationGuide() {
    Get.dialog(
      AlertDialog(
        title: const Text('Samsung GPS Optimization Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Follow these steps for optimal GPS tracking on Samsung devices:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Location Settings:'),
              Text('   • Go to Settings → Location → Mode'),
              Text('   • Select "High accuracy"'),
              SizedBox(height: 8),
              Text('2. App Battery Settings:'),
              Text('   • Settings → Apps → This App → Battery'),
              Text('   • Enable "Allow background activity"'),
              Text('   • Disable "Put unused apps to sleep"'),
              SizedBox(height: 8),
              Text('3. Location Permissions:'),
              Text('   • Settings → Apps → This App → Permissions'),
              Text('   • Location: "Allow all the time"'),
              SizedBox(height: 8),
              Text('4. Additional Settings:'),
              Text('   • Settings → Battery → App power management'),
              Text('   • Add this app to "Never sleeping apps"'),
              SizedBox(height: 8),
              Text('5. One UI Specific:'),
              Text('   • Settings → Device care → Battery → App power management'),
              Text('   • Find this app and set to "Unmonitored app"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Check if current settings are optimal for Samsung
  Future<bool> checkOptimizationStatus() async {
    if (!isSamsungDevice.value) return true;
    
    // This would ideally check actual system settings
    // For now, we'll assume they need optimization
    hasOptimizedSettings.value = false;
    return false;
  }

  /// Get troubleshooting steps for GPS issues
  List<String> getGpsTroubleshootingSteps() {
    return [
      'Ensure location services are enabled',
      'Set location mode to "High accuracy"',
      'Disable battery optimization for this app',
      'Allow background location access',
      'Move to an open area for better GPS signal',
      'Restart the app if GPS stops working',
      'Check if any power-saving modes are active',
    ];
  }
}
