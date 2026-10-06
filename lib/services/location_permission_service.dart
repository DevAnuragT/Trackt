import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'samsung_permission_helper.dart';

class LocationPermissionService extends GetxService {
  static const String _hasShownAllowAllDialogKey = 'hasShownAllowAllDialog';
  static const String _hasShownLocationRequiredDialogKey = 'hasShownLocationRequiredDialog';
  
  late SharedPreferences _prefs;
  
  // Add flags to prevent multiple dialogs from showing simultaneously
  bool _isShowingLocationServiceDialog = false;
  bool _isShowingPermissionDialog = false;
  bool _isShowingPermanentlyDeniedDialog = false;
  bool _isShowingAllowAllTimeDialog = false;
  
  @override
  void onInit() {
    super.onInit();
    _initPreferences();
  }
  
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Check if location services are enabled and show appropriate dialog if not
  Future<bool> checkLocationServiceEnabled() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        // Prevent multiple dialogs from showing
        if (_isShowingLocationServiceDialog) {
          print('⚠️ Location service dialog already showing, skipping...');
          return false;
        }
        
        // Show location service required dialog
        bool shouldShowDialog = !(_prefs.getBool(_hasShownLocationRequiredDialogKey) ?? false);
        
        if (shouldShowDialog) {
          _isShowingLocationServiceDialog = true;
          await _showLocationServiceRequiredDialog();
          _isShowingLocationServiceDialog = false;
          await _prefs.setBool(_hasShownLocationRequiredDialogKey, true);
        } else {
          // Show simple snackbar for repeat attempts
          Get.snackbar(
            'Location Services Disabled',
            'Please enable location services in your device settings',
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error checking location service enabled: $e');
      return false;
    }
  }
  
  /// Check location permissions and show appropriate dialogs
  Future<bool> checkLocationPermissions() async {
    try {
      print('🔍 Checking location permissions...');
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission status: $permission');
      
      switch (permission) {
        case LocationPermission.denied:
          print('🔐 Permission denied, requesting...');
          
          // Prevent multiple dialogs from showing
          if (_isShowingPermissionDialog) {
            print('⚠️ Permission dialog already showing, skipping...');
            return false;
          }
          
          // Request permission
          permission = await Geolocator.requestPermission();
          print('📍 Permission request result: $permission');
          
          if (permission == LocationPermission.denied) {
            print('❌ Permission still denied after request');
            // Show permission denied dialog immediately
            _isShowingPermissionDialog = true;
            await _showPermissionDeniedDialog();
            _isShowingPermissionDialog = false;
            return false;
          }
          // Fall through to check if we need to request background permission
          break;
          
        case LocationPermission.deniedForever:
          print('❌ Permission permanently denied');
          
          // Prevent multiple dialogs from showing
          if (_isShowingPermanentlyDeniedDialog) {
            print('⚠️ Permanently denied dialog already showing, skipping...');
            return false;
          }
          
          // Show permanently denied dialog immediately
          _isShowingPermanentlyDeniedDialog = true;
          await _showPermissionDeniedForeverDialog();
          _isShowingPermanentlyDeniedDialog = false;
          return false;
          
        case LocationPermission.whileInUse:
          print('✅ While in use permission granted');
          // Check if we need to request background permission (Android 10+)
          if (Platform.isAndroid) {
            return await _checkBackgroundPermission();
          }
          return true;
          
        case LocationPermission.always:
          print('✅ Always permission granted');
          return true;
          
        default:
          print('❓ Unknown permission status: $permission');
          return false;
      }
      
      bool hasValidPermission = permission == LocationPermission.whileInUse || 
                               permission == LocationPermission.always;
      print('📍 Final permission result: ${hasValidPermission ? 'GRANTED' : 'DENIED'}');
      return hasValidPermission;
    } catch (e) {
      print('❌ Error checking location permissions: $e');
      return false;
    }
  }
  
  /// Check and request background location permission if needed
  Future<bool> _checkBackgroundPermission() async {
    try {
      print('🔍 Checking background location permission...');
      
      // Check if we should show the "Allow all the time" dialog
      bool hasShownDialog = _prefs.getBool(_hasShownAllowAllDialogKey) ?? false;
      print('📍 Has shown allow all time dialog: $hasShownDialog');
      
      if (!hasShownDialog) {
        // Prevent multiple dialogs from showing
        if (_isShowingAllowAllTimeDialog) {
          print('⚠️ Allow all time dialog already showing, skipping...');
          return true; // Allow tracking with whileInUse permission
        }
        
        print('📱 Showing allow all time dialog immediately...');
        _isShowingAllowAllTimeDialog = true;
        bool acknowledged = await _showAllowAllTimeDialog();
        _isShowingAllowAllTimeDialog = false;
        print('📍 User acknowledged dialog: $acknowledged');
        
        await _prefs.setBool(_hasShownAllowAllDialogKey, true);
        
        if (acknowledged) {
          print('🔧 User wants to open app settings...');
          // Take user to app settings so they can choose "Allow all the time"
          try {
            await _openAppSettingsWithFallback();
          } catch (e) {
            print('❌ Error opening app settings: $e');
          }
        }
      } else {
        print('ℹ️ User has seen dialog before, showing snackbar');
        // If user has seen the dialog before, just show a snackbar
        Get.snackbar(
          'Background Location Recommended',
          'For continuous tracking, consider allowing "All the time" in location settings',
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      }
      
      print('✅ Background permission check completed');
      return true; // Allow tracking with whileInUse permission
    } catch (e) {
      print('❌ Error checking background permission: $e');
      return true; // Fallback to allow tracking
    }
  }

  /// Public helper: show the "Allow all the time" dialog once and open app settings
  Future<void> maybeShowAllowAllTimeDialogAndOpenSettings() async {
    try {
      bool hasShownDialog = _prefs.getBool(_hasShownAllowAllDialogKey) ?? false;
      if (!hasShownDialog) {
        bool acknowledged = await _showAllowAllTimeDialog();
        await _prefs.setBool(_hasShownAllowAllDialogKey, true);
        if (acknowledged) {
          try {
            await Geolocator.openAppSettings();
          } catch (e) {
            print('Error opening app settings: $e');
          }
        }
      }
    } catch (e) {
      print('Error in maybeShowAllowAllTimeDialogAndOpenSettings: $e');
    }
  }
  
  /// Show dialog explaining why location services are required
  Future<void> _showLocationServiceRequiredDialog() async {
    return Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Location Service Required',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Location services are currently disabled on your device. '
          'To track your runs and claim territory, you need to enable location services.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Turn On'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
  
  /// Show dialog for permission denied
  Future<void> _showPermissionDeniedDialog() async {
    return Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Location Permission Denied',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Location permission is required to track your runs and claim territory. '
          'Please grant location permission to continue.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              Geolocator.requestPermission();
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Grant Permission'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
  
  /// Show dialog for permission permanently denied
  Future<void> _showPermissionDeniedForeverDialog() async {
    return Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Location Permission Blocked',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Location permission has been permanently denied. '
          'You need to enable it manually in your device settings to track runs.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              Geolocator.openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
  
  /// Show dialog explaining why "Allow all the time" is beneficial
  Future<bool> _showAllowAllTimeDialog() async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.track_changes, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Better Run Tracking',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Allowing location access "All the time" will:\n\n'
          '• Track your runs even when the app is in the background\n'
          '• Provide more accurate territory boundaries\n'
          '• Ensure no GPS data is lost during your run\n\n'
          'This is especially important for longer runs where you might need to check other apps.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back(result: true);
              // Try to open app settings with proper error handling
              await _openAppSettingsWithFallback();
            },
            icon: const Icon(Icons.check),
            label: const Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    
    return result ?? false;
  }

  /// Open app settings with fallback mechanisms for different devices
  Future<void> _openAppSettingsWithFallback() async {
    try {
      print('🔧 Attempting to open app settings...');
      
      // Check if this is a Samsung device
      final samsungHelper = Get.find<SamsungPermissionHelper>();
      bool isSamsung = samsungHelper.isSamsungDevice.value;
      
      if (isSamsung) {
        print('📱 Samsung device detected, trying Samsung-specific method...');
        // Try Samsung-specific package URL method
        try {
          final Uri samsungSettingsUri = Uri.parse('package:com.devanuragt.starlink_outpost_app');
          await launchUrl(samsungSettingsUri, mode: LaunchMode.externalApplication);
          print('✅ Samsung: App settings opened via package URL');
          return;
        } catch (e) {
          print('❌ Samsung: Package URL method failed: $e');
          // Fall back to standard method
        }
      }
      
      // First try: Use Geolocator.openAppSettings()
      await Geolocator.openAppSettings();
      print('✅ App settings opened successfully via Geolocator');
      
    } catch (e) {
      print('❌ Geolocator.openAppSettings() failed: $e');
      
      try {
        // Second try: Use app_settings package if available
        // Note: You may need to add app_settings: ^2.0.3 to pubspec.yaml
        // import 'package:app_settings/app_settings.dart';
        // await AppSettings.openAppSettings();
        
        // For now, show manual instructions
        _showManualSettingsInstructions();
        
      } catch (e2) {
        print('❌ Fallback app settings also failed: $e2');
        _showManualSettingsInstructions();
      }
    }
  }

  /// Show manual instructions for opening app settings
  void _showManualSettingsInstructions() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Open Settings Manually',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Please follow these steps to enable background location:\n\n'
          '1. Go to your device Settings\n'
          '2. Find "Apps" or "Application Manager"\n'
          '3. Find "Trackt" in the list\n'
          '4. Tap "Permissions"\n'
          '5. Tap "Location"\n'
          '6. Select "Allow all the time"\n\n'
          'This will ensure your runs are tracked continuously.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              // Try to open general settings as a last resort
              _tryOpenGeneralSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'I\'ll Do It Later',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Try to open general device settings as a last resort
  void _tryOpenGeneralSettings() {
    try {
      // This is a more aggressive approach that should work on most devices
      
      // Try to open general settings
      final Uri settingsUri = Uri.parse('package:com.devanuragt.starlink_outpost_app');
      
      launchUrl(settingsUri, mode: LaunchMode.externalApplication).catchError((e) {
        print('❌ Could not open settings via URL: $e');
        // Show final fallback message
        Get.snackbar(
          'Settings Not Accessible',
          'Please manually go to Settings > Apps > Trackt > Permissions > Location > Allow all the time',
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return false;
      });
      
    } catch (e) {
      print('❌ General settings fallback failed: $e');
      // Show final fallback message
      Get.snackbar(
        'Settings Not Accessible',
        'Please manually go to Settings > Apps > Trackt > Permissions > Location > Allow all the time',
        duration: const Duration(seconds: 8),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }
  
  /// Reset dialog preferences (useful for testing)
  Future<void> resetDialogPreferences() async {
    await _prefs.remove(_hasShownAllowAllDialogKey);
    await _prefs.remove(_hasShownLocationRequiredDialogKey);
    print('🔄 Dialog preferences reset for testing');
  }
  
  /// Reset dialog flags (useful for debugging stuck dialogs)
  void resetDialogFlags() {
    _isShowingLocationServiceDialog = false;
    _isShowingPermissionDialog = false;
    _isShowingPermanentlyDeniedDialog = false;
    _isShowingAllowAllTimeDialog = false;
    print('🔄 Dialog flags reset');
  }
  
  /// Check if any permission dialogs are currently showing
  bool get isAnyDialogShowing => _isShowingLocationServiceDialog || 
                                 _isShowingPermissionDialog || 
                                 _isShowingPermanentlyDeniedDialog || 
                                 _isShowingAllowAllTimeDialog;
  
  /// Force reset all permission states (useful for testing edge cases)
  Future<void> forceResetAllPermissionStates() async {
    await resetDialogPreferences();
    resetDialogFlags();
    print('🔄 All permission states have been force reset');
  }
  
  /// Test method to verify permission flow (useful for debugging)
  Future<void> testPermissionFlow() async {
    print('🧪 Testing location permission flow...');
    
    try {
      // Test location service enabled check
      print('1️⃣ Testing location service enabled...');
      bool serviceEnabled = await checkLocationServiceEnabled();
      print('📍 Location service enabled: $serviceEnabled');
      
      if (serviceEnabled) {
        // Test location permission check
        print('2️⃣ Testing location permissions...');
        bool hasPermission = await checkLocationPermissions();
        print('📍 Location permission result: $hasPermission');
        
        // Test current permission status
        print('3️⃣ Current permission status...');
        LocationPermission currentPermission = await Geolocator.checkPermission();
        print('📍 Current permission: $currentPermission');
        
        // Test if we can get current position
        if (hasPermission) {
          print('4️⃣ Testing current position...');
          try {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
            print('✅ Got position: ${position.latitude}, ${position.longitude}');
          } catch (e) {
            print('❌ Failed to get position: $e');
          }
        }
      }
      
      print('🧪 Permission flow test completed');
    } catch (e) {
      print('❌ Error during permission flow test: $e');
    }
  }
  
  /// Test the smart permission check system
  Future<void> testSmartPermissionCheck() async {
    print('🧠 Testing smart permission check system...');
    
    try {
      print('1️⃣ Testing smart check without force...');
      bool result1 = await smartCheckLocationPermissions(forceCheck: false);
      print('📍 Smart check result: $result1');
      
      print('2️⃣ Testing smart check with force...');
      bool result2 = await smartCheckLocationPermissions(forceCheck: true);
      print('📍 Force check result: $result2');
      
      print('3️⃣ Testing if any dialogs are showing...');
      print('📍 Any dialogs showing: $isAnyDialogShowing');
      
      print('4️⃣ Testing valid permissions check...');
      bool hasValid = await hasValidLocationPermissions();
      print('📍 Has valid permissions: $hasValid');
      
      print('🧠 Smart permission check test completed');
    } catch (e) {
      print('❌ Error during smart permission check test: $e');
    }
  }
  
  /// Check if user has seen the "Allow all the time" dialog
  bool get hasShownAllowAllDialog => _prefs.getBool(_hasShownAllowAllDialogKey) ?? false;
  
  /// Check if user has seen the location service required dialog
  bool get hasShownLocationRequiredDialog => _prefs.getBool(_hasShownLocationRequiredDialogKey) ?? false;
  
  /// Check if we already have valid location permissions (without showing dialogs)
  Future<bool> hasValidLocationPermissions() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('Error checking if we have valid permissions: $e');
      return false;
    }
  }
  
  /// Smart permission check that only shows dialogs when necessary
  Future<bool> smartCheckLocationPermissions({bool forceCheck = false}) async {
    try {
      print('🧠 Smart permission check called (forceCheck: $forceCheck)');
      
      // If we already have valid permissions and not forcing a check, return true
      if (!forceCheck) {
        bool hasValid = await hasValidLocationPermissions();
        if (hasValid) {
          print('✅ Already have valid location permissions, skipping dialog checks');
          return true;
        }
        print('⚠️ No valid permissions found, proceeding with full permission check');
      } else {
        print('🔄 Force check requested, proceeding with full permission check');
      }
      
      // Check if any dialogs are already showing
      if (isAnyDialogShowing) {
        print('⚠️ Permission dialogs already showing, skipping this check');
        return false;
      }
      
      // Otherwise, do the full permission check with dialogs
      return await checkLocationPermissions();
    } catch (e) {
      print('Error in smart permission check: $e');
      return false;
    }
  }
}
