import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../models/territory/territory_model.dart';
// import 'package:device_info_plus/device_info_plus.dart';

class LocationService extends GetxService {
  // Observable current location
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxBool hasLocationPermission = false.obs;
  final RxBool isLocationServiceEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Check location permissions immediately on initialization
    _checkLocationPermission();
    // _checkDeviceType();
  }

  Future<bool> _checkLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    isLocationServiceEnabled.value = serviceEnabled;
    
    if (!serviceEnabled) {
      // Note: Permission dialogs will be handled by LocationPermissionService
      // This method just updates the internal state
      hasLocationPermission.value = false;
      return false;
    }

    // Check location permissions without requesting them automatically
    LocationPermission permission = await Geolocator.checkPermission();
    
    // Only update internal state, don't request permissions automatically
    // This prevents black screen issues during app startup
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      hasLocationPermission.value = false;
      return false;
    }
    
    // Check for background location permission on Android 10+
    if (Platform.isAndroid) {
      try {
        // Note: Background permission dialogs will be handled by LocationPermissionService
        if (permission == LocationPermission.whileInUse) {
          print('📍 Background location permission check - dialogs handled by LocationPermissionService');
        }
      } catch (e) {
        print('Background location permission check failed: $e');
      }
    }

    hasLocationPermission.value = true;
    _getCurrentLocation();
    return true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation, // Highest accuracy
        timeLimit: const Duration(seconds: 15), // Allow time for GPS fix
      );
      currentPosition.value = position;
      print('✅ Location service updated current position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  /// Force refresh current location
  Future<void> refreshCurrentLocation() async {
    print('🔄 Location service: Forcing location refresh...');
    await _getCurrentLocation();
  }

  /// Get current position (simple method)
  Future<Position?> getCurrentPosition() async {
    if (currentPosition.value != null) {
      return currentPosition.value;
    }
    return await getHighAccuracyLocation();
  }

  /// Get high-accuracy location fix for precise positioning
  Future<Position?> getHighAccuracyLocation() async {
    try {
      // Wait for the best possible GPS fix
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 30), // ✅ Increased from 20 to 30 seconds for better GPS fix
      );
      
      // If accuracy is still poor, try again with a different approach
      if (position.accuracy > 10.0) {
        print('GPS accuracy poor (±${position.accuracy}m), trying again...');
        
        // Get multiple readings and use the most accurate one
        List<Position> readings = [];
        for (int i = 0; i < 3; i++) {
          try {
            Position reading = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.bestForNavigation,
              timeLimit: const Duration(seconds: 15), // ✅ Increased from 5 to 15 seconds
            );
            readings.add(reading);
            await Future.delayed(const Duration(seconds: 1));
          } catch (e) {
            print('Reading $i failed: $e');
          }
        }
        
        if (readings.isNotEmpty) {
          // Return the most accurate reading
          position = readings.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
        }
      }
      
      currentPosition.value = position;
      print('Final GPS accuracy: ±${position.accuracy}m');
      return position;
    } catch (e) {
      print('Error getting high-accuracy location: $e');
      
      // Provide specific error messages for common GPS issues
      if (e.toString().contains('TimeoutException')) {
        print('⚠️ GPS timeout - device may need more time to get GPS fix');
        print('💡 Try moving to an open area or waiting a few more seconds');
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        print('❌ Location permission denied');
      } else if (e.toString().contains('LOCATION_SERVICE_DISABLED')) {
        print('❌ Location services disabled');
      }
      
      return null;
    }
  }

  Future<bool> requestLocationPermission() async {
    // This method now properly requests permissions and updates internal state
    try {
      print('🔍 Requesting location permission...');
      
      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      isLocationServiceEnabled.value = serviceEnabled;
      
      if (!serviceEnabled) {
        print('❌ Location services disabled');
        hasLocationPermission.value = false;
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        print('🔐 Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        print('📍 Permission request result: $permission');
        
        if (permission == LocationPermission.denied) {
          print('❌ Permission still denied after request');
          hasLocationPermission.value = false;
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission permanently denied');
        hasLocationPermission.value = false;
        return false;
      }

      // Permission granted
      print('✅ Location permission granted: $permission');
      hasLocationPermission.value = true;
      
      // Get current location if permission is granted
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await _getCurrentLocation();
      }
      
      return true;
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      hasLocationPermission.value = false;
      return false;
    }
  }

  // Stream location updates for run tracking with maximum accuracy
  Stream<Position> getLocationStream() {
    if (Platform.isIOS) {
      // iOS-specific settings for background location tracking
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, // Highest GPS accuracy
          distanceFilter: 2, // Update every 2 meters
          // iOS background location settings
          timeLimit: null, // No time limit for continuous tracking
        ),
      );
    } else {
      // Android settings with Samsung-specific optimizations
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, // Highest GPS accuracy
          distanceFilter: 2, // Update every 2 meters
          // Remove timeLimit to prevent GPS timeouts during tracking
        ),
      );
    }
  }

  // Convert Position to LatLngPoint
  LatLngPoint positionToLatLngPoint(Position position) {
    return LatLngPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      speed: position.speed,
    );
  }

  // Calculate distance between two positions
  double calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // Check if location is within radius (for territory loading)
  bool isWithinRadius(LatLngPoint center, LatLngPoint point, double radiusInMeters) {
    double distance = center.distanceTo(point);
    return distance <= radiusInMeters;
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
