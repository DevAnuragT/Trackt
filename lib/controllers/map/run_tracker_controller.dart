import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/territory/run_session_model.dart';
import '../../models/territory/territory_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/location_permission_service.dart';
import '../../services/territory_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../core/enums/run_state.dart';
import '../../services/run_storage_service.dart';
import '../../views/map/components/bottom_sheet_widget.dart';
import '../../services/samsung_permission_helper.dart';

class RunTrackerController extends GetxController {
  // Dependencies
  final LocationService _locationService = Get.find<LocationService>();
  final LocationPermissionService _permissionService = Get.find<LocationPermissionService>();
  final RunStorageService _runStorageService = Get.find<RunStorageService>();
  final TerritoryService _territoryService = Get.find<TerritoryService>();
  final Uuid _uuid = const Uuid();
  final DatabaseService _databaseService = Get.find<DatabaseService>();
  final SamsungPermissionHelper _samsungHelper = Get.find<SamsungPermissionHelper>();

  
  // Observable run state
  final Rx<RunState> runState = RunState.idle.obs;
  final Rx<RunSession?> currentRunSession = Rx<RunSession?>(null);
  final RxBool isRunning = false.obs;
  final RxBool isPaused = false.obs;
  final RxBool isStartingRun = false.obs; // Loading state for run start
  final RxBool isUploadingTerritory = false.obs; // Loading state for territory upload
  final RxDouble totalDistance = 0.0.obs;
  final Rx<Duration> runDuration = const Duration().obs;
  final RxList<LatLngPoint> currentPath = <LatLngPoint>[].obs;
  
  // Path customization
  final Rx<Color> selectedPathColor = const Color(0xFF2196F3).obs;
  static const List<Color> pathColors = [
    Colors.blue,       // Default (moved to first)
    Colors.black,      // Classic
    Colors.red,        // Bold
    Colors.green,      // Nature
    Colors.purple,     // Royal
    Colors.orange,     // Energetic
    Colors.teal,       // Ocean
    Colors.pink,       // Vibrant
  ];
  
  // Map tracking
  MapboxMap? _runMap;
  String? _pathLineLayerId;
  String? _dottedLineLayerId;
  
  // Internal tracking
  StreamSubscription<geo.Position>? _locationSubscription;
  Timer? _durationTimer;
  Timer? _gpsHealthCheckTimer; // Monitor GPS health
  DateTime? _runStartTime;
  DateTime? _lastGpsUpdate; // Track when we last received GPS data
  int _gpsRestartCount = 0; // Track GPS restart attempts
  geo.Position? _lastPosition;
  final List<LatLngPoint> _rawPathPoints = [];
  
  // Territory creation state
  bool _isProcessingTerritory = false;
  
  // Noise filtering - made more lenient for testing
  static const double _maxAccuracy = 50.0; // meters - more lenient for testing
  static const double _minDistanceThreshold = 1.0; // meters - more sensitive for testing
  
  @override
  void onInit() {
    super.onInit();
    ever(isRunning, _onRunStateChanged);
    _initializeUserColor();
    
    // Add a delayed initialization to ensure UserPreferencesService is fully loaded from Supabase
    Future.delayed(const Duration(milliseconds: 1000), () {
      refreshUserColor();
    });
    
    // React to changes in user color preferences
    try {
      final prefs = Get.find<UserPreferencesService>();
      ever(prefs.userColor, (Color newColor) {
        selectedPathColor.value = newColor;
        print('🎨 [REACTIVE] Color changed to: $newColor');
        print('🎨 [REACTIVE] Color hex: #${newColor.value.toRadixString(16).padLeft(8, '0')}');
        
        // Update current run path if running
        if (isRunning.value && _runMap != null) {
          _updateRunPathColor();
        }
      });
    } catch (e) {
      print('⚠️ Could not set up reactive color listener: $e');
    }
  }

  // Initialize with user's selected color from preferences
  void _initializeUserColor() async {
    try {
      final prefs = Get.find<UserPreferencesService>();
      selectedPathColor.value = prefs.userColor.value;
      print('🎨 [INIT] Initialized run path color: ${selectedPathColor.value}');
      print('🎨 [INIT] Color hex: #${selectedPathColor.value.value.toRadixString(16).padLeft(8, '0')}');
    } catch (e) {
      print('⚠️ Could not load user color preferences: $e');
      // Try to initialize UserPreferencesService if not available
      try {
        final prefs = await Get.putAsync(() => UserPreferencesService().init());
        selectedPathColor.value = prefs.userColor.value;
        print('🎨 [LATE-INIT] Late-initialized run path color: ${selectedPathColor.value}');
        print('🎨 [LATE-INIT] Color hex: #${selectedPathColor.value.value.toRadixString(16).padLeft(8, '0')}');
      } catch (e2) {
        print('⚠️ Failed to late-initialize user color preferences: $e2');
        // Keep default blue color
      }
    }
  }

  // Refresh color from user preferences (call this when user changes color preference)
  void refreshUserColor() {
    try {
      final prefs = Get.find<UserPreferencesService>();
      selectedPathColor.value = prefs.userColor.value;
      print('🎨 [REFRESH] Refreshed run path color: ${selectedPathColor.value}');
      print('🎨 [REFRESH] Color hex: #${selectedPathColor.value.value.toRadixString(16).padLeft(8, '0')}');
      
      // Update the current run path color if a run is in progress
      if (isRunning.value && _runMap != null) {
        _updateRunPathColor();
      }
    } catch (e) {
      print('⚠️ Could not refresh user color preferences: $e');
    }
  }

  // Update the current run path color on the map
  void _updateRunPathColor() async {
    if (_runMap == null || _rawPathPoints.length < 2) return;
    
    try {
      // Remove existing path
      if (_pathLineLayerId != null) {
        await _runMap!.style.removeStyleLayer(_pathLineLayerId!);
        await _runMap!.style.removeStyleSource('run-path-source');
        _pathLineLayerId = null;
      }
    } catch (e) {
      // Ignore if layers don't exist
    }
    
    // Re-add path with new color
    _updateLivePathOnMap();
  }

  @override
  void onClose() {
    _stopLocationTracking();
    _durationTimer?.cancel();
    super.onClose();
  }

  void _onRunStateChanged(bool running) {
    if (running) {
      _startLocationTracking();
      _startDurationTimer();
    } else {
      _stopLocationTracking();
      _durationTimer?.cancel();
    }
  }

  /// Initialize the run tracking map
  void initializeRunMap(MapboxMap map) {
    _runMap = map;
    print('🗺️ Run tracking map initialized successfully');
    print('🗺️ Map object: ${_runMap != null ? "Available" : "NULL"}');
    
    // Set up location following when run starts
    _setupLocationFollowing();
  }
  
  void _setupLocationFollowing() async {
    if (_runMap == null) return;
    try {
      // Enable location component for live tracking
      await _runMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        locationPuck: LocationPuck(
          locationPuck2D: DefaultLocationPuck2D(),
        ),
      ));
      
      print('Location following enabled for run tracking');
    } catch (e) {
      print('Error setting up location following: $e');
    }
  }
  
  Future<void> _centerMapOnUser(geo.Position position) async {
    if (_runMap == null) return;
    
    try {
      // Animate camera to user location with close zoom for run tracking
      await _runMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(
            position.longitude,
            position.latitude,
          )),
          zoom: 17.0, // Close zoom for detailed tracking
          bearing: 0.0,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 2000), // 2 second animation
      );
      
      print('Map centered on user location for run tracking');
    } catch (e) {
      print('Error centering map on user: $e');
    }
  }

  Future<bool> startRun() async {
    if (isRunning.value || runState.value != RunState.idle) return false;
    
    // Set loading state
    isStartingRun.value = true;
    
    print('🚀 Starting run - checking permissions and GPS...');
    
    // Reset GPS restart counter for new run
    _gpsRestartCount = 0;
    
    // Get the current context for permission dialogs
    BuildContext? context = Get.context;
    if (context == null) {
      print('❌ No context available for permission dialogs');
      isStartingRun.value = false;
      return false;
    }
    
    // Use smart permission check to avoid duplicate dialogs
    print('🔍 Checking location permissions...');
    bool hasPermission = await _permissionService.smartCheckLocationPermissions();
    print('📍 Location permission: ${hasPermission ? 'GRANTED' : 'DENIED'}');
    
    if (!hasPermission) {
      print('❌ Location permission denied');
      isStartingRun.value = false;
      return false;
    }

    // Get current position for starting point
    try {
      print('📡 Getting initial GPS position...');
      geo.Position currentPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
      
      print('✅ Got initial position: ${currentPosition.latitude}, ${currentPosition.longitude} (±${currentPosition.accuracy}m)');
      
      // Only reset tracking data if this is a fresh run (not resuming)
      if (currentRunSession.value == null || currentRunSession.value!.status == RunStatus.cancelled) {
        print('🔄 Starting fresh run - resetting tracking data');
        _resetTrackingData();
      } else {
        print('🔄 Resuming existing run - keeping existing tracking data');
      }
      
      // Create new run session or update existing one
      if (currentRunSession.value == null) {
        _runStartTime = DateTime.now();
        currentRunSession.value = RunSession(
          id: _uuid.v4(),
          userId: 'current_user', // TODO: Get from auth
          startTime: _runStartTime!,
          rawPath: [],
          status: RunStatus.active,
        );
      } else {
        // Update existing run session
        currentRunSession.value = currentRunSession.value!.copyWith(
          status: RunStatus.active,
        );
        print('🔄 Updated existing run session status to active');
      }
      
      // Add starting point only if this is a fresh run
      if (currentRunSession.value!.rawPath.isEmpty) {
        LatLngPoint startPoint = _locationService.positionToLatLngPoint(currentPosition);
        _addTrackingPoint(startPoint);
        _lastPosition = currentPosition;
        print('📍 Added starting point for fresh run');
      } else {
        print('📍 Keeping existing path points for resumed run');
      }

      runState.value = RunState.running;
      isRunning.value = true;
      isPaused.value = false;
      
      // Start actual tracking
      _startLocationTracking();
      _startDurationTimer();
      

      
      // Center map on user location for run tracking
      await _centerMapOnUser(currentPosition);
      
      Get.snackbar(
        'Run Started',
        'Your run has started. Go claim some territory!',
        duration: const Duration(seconds: 2),
      );
      
      // Clear loading state
      isStartingRun.value = false;
      
      return true;
    } catch (e) {
      print('❌ Failed to start run: $e');
      
      String errorMessage = 'Failed to start run: ';
      
      // Provide specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage += 'Location permission was denied';
      } else if (e.toString().contains('LOCATION_SERVICE_DISABLED')) {
        errorMessage += 'Location services are disabled';
      } else if (e.toString().contains('TIMEOUT') || e.toString().contains('TimeoutException')) {
        errorMessage += 'GPS timeout. Try moving to an open area or wait longer';
      } else if (e.toString().contains('LOCATION_REQUEST_TIMEOUT')) {
        errorMessage += 'GPS took too long to respond';
      } else {
        errorMessage += 'GPS error. Check location settings';
      }
      
      Get.snackbar(
        'Cannot Start Run',
        errorMessage,
        duration: const Duration(seconds: 4),
      );
      
      // Show Samsung-specific help if applicable
      if (_samsungHelper.isSamsungDevice.value) {
        _samsungHelper.showDetailedOptimizationGuide();
      }
      
      // Clear loading state on error
      isStartingRun.value = false;
      
      return false;
    }
  }

  void stopRun() async {
    print('🛑 stopRun() called');
    print('🛑 Current run state: ${runState.value}');
    print('🛑 isRunning: ${isRunning.value}');
    print('🛑 isPaused: ${isPaused.value}');
    
  if (!isRunning.value && !isPaused.value) {
      print('⚠️ stopRun() called but not running, returning early');
      return;
    }
    
    print('🛑 Stopping run...');
    runState.value = RunState.finished;
  isRunning.value = false;
  isPaused.value = false;
    isStartingRun.value = false; // Clear loading state
    
    // Reset GPS tracking state
    _lastGpsUpdate = null;
    _gpsRestartCount = 0;
    
    // Stop all tracking
    _stopLocationTracking();
    _durationTimer?.cancel();
    

    
    // Update run session
    if (currentRunSession.value != null) {
      print('🔄 Updating run session with final data...');
      print('🔄 Raw path points count: ${_rawPathPoints.length}');
      print('🔄 Total distance: ${totalDistance.value.toStringAsFixed(2)}m');
      print('🔄 Run duration: ${runDuration.value.inSeconds}s');
      
      currentRunSession.value = currentRunSession.value!.copyWith(
        endTime: DateTime.now(),
        distance: totalDistance.value,
        duration: runDuration.value,
        rawPath: List.from(_rawPathPoints),
        status: RunStatus.completed,
      );
      
      // Save completed run to history
      await _runStorageService.saveRun(currentRunSession.value!);
      print('✅ Run session updated and saved');
    } else {
      print('⚠️ No current run session to update');
    }
    
    Get.snackbar(
      'Run Completed',
      'Distance: ${(totalDistance.value / 1000).toStringAsFixed(2)} km',
      duration: const Duration(seconds: 3),
    );
    
    // Process territory creation
    print('🗺️ Calling territory creation process...');
    print('🗺️ About to call _processTerritoryCreation()');
    _processTerritoryCreation();
    print('🗺️ _processTerritoryCreation() call completed');
  }

  void pauseRun() async {
    if (!isRunning.value) return;
    
    runState.value = RunState.paused;
    isRunning.value = false;
    isPaused.value = true;
    
    // Stop tracking and timer during pause
    _stopLocationTracking();
    _durationTimer?.cancel();
    

    
    Get.snackbar(
      'Run Paused',
      'Your run has been paused',
      duration: const Duration(seconds: 2),
    );
  }

  void resumeRun() async {
    if (isRunning.value || currentRunSession.value == null) return;
    
    runState.value = RunState.running;
    isRunning.value = true;
    isPaused.value = false;
    
    // Resume tracking and timer
    _startLocationTracking();
    _startDurationTimer();
    

    
    Get.snackbar(
      'Run Resumed',
      'Your run has been resumed',
      duration: const Duration(seconds: 2),
    );
  }

  void cancelRun() async {
    if (currentRunSession.value == null) return;
    
    isRunning.value = false;
    
    // Update run session status
    currentRunSession.value = currentRunSession.value!.copyWith(
      status: RunStatus.cancelled,
    );
    

    
    _resetTrackingData();
    
    Get.snackbar(
      'Run Cancelled',
      'Your run has been cancelled',
      duration: const Duration(seconds: 2),
    );
  }

  void _resetTrackingData() {
    print('🔄 Resetting tracking data...');
    print('🔄 Previous raw path points: ${_rawPathPoints.length}');
    print('🔄 Previous total distance: ${totalDistance.value.toStringAsFixed(2)}m');
    
    totalDistance.value = 0.0;
    runDuration.value = const Duration();
    currentPath.clear();
    _rawPathPoints.clear();
    _lastPosition = null;
    _runStartTime = null;
    
    print('✅ Tracking data reset complete');
  }

  void _startLocationTracking() {
    // Cancel any existing subscription first
    _stopLocationTracking();
    
    print('🔄 Starting GPS location tracking...');
    
    // Start GPS health monitoring
    _startGpsHealthCheck();
    
    _locationSubscription = _locationService.getLocationStream().listen(
      _onLocationUpdate,
      onError: (error) {
        print('❌ Location stream error: $error');
        print('Error type: ${error.runtimeType}');
        
        // Only show error if we're actually running (not stopped)
        if (isRunning.value) {
          String errorMessage = 'GPS tracking interrupted. ';
          
          // Provide specific error messages based on error type
          if (error.toString().contains('PERMISSION_DENIED')) {
            errorMessage += 'Location permission was denied.';
          } else if (error.toString().contains('LOCATION_SERVICE_DISABLED')) {
            errorMessage += 'Location services are disabled.';
          } else if (error.toString().contains('TimeoutException')) {
            errorMessage += 'Reconnecting to GPS...';
          } else {
            errorMessage += 'Check your location settings.';
          }
          
          Get.snackbar(
            'GPS Notice',
            errorMessage,
            duration: const Duration(seconds: 2),
          );
          
          // Auto-restart GPS tracking after timeout errors
          if (error.toString().contains('TimeoutException') || 
              error.toString().contains('Time limit reached') ||
              error.toString().contains('position update')) {
            print('🔄 GPS timeout detected, restarting location tracking in 3 seconds...');
            
            // Limit restart attempts to prevent infinite loops
            if (_gpsRestartCount < 5) {
              _gpsRestartCount++;
              Future.delayed(const Duration(seconds: 3), () {
                if (isRunning.value) {
                  print('🔄 Restarting GPS location tracking (attempt $_gpsRestartCount)...');
                  _startLocationTracking();
                }
              });
            } else {
              print('⚠️ Maximum GPS restart attempts reached');
              Get.snackbar(
                'GPS Issue',
                'GPS keeps timing out. Try moving to an open area.',
                duration: const Duration(seconds: 4),
              );
            }
          }
        }
      },
      onDone: () {
        print('⚠️ Location stream ended');
        if (isRunning.value) {
          print('🔄 GPS stream ended during run, attempting to restart...');
          Get.snackbar(
            'GPS Reconnecting',
            'GPS connection lost, trying to reconnect...',
            duration: const Duration(seconds: 2),
          );
          
          // Restart GPS tracking after a short delay
          if (_gpsRestartCount < 5) {
            _gpsRestartCount++;
            Future.delayed(const Duration(seconds: 2), () {
              if (isRunning.value) {
                print('🔄 Restarting GPS after stream ended (attempt $_gpsRestartCount)...');
                _startLocationTracking();
              }
            });
          } else {
            print('⚠️ Maximum GPS restart attempts reached');
            Get.snackbar(
              'GPS Issue',
              'GPS connection keeps failing. Check your location settings.',
              duration: const Duration(seconds: 2),
            );
          }
        }
      },
    );
  }

  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    // Stop GPS health monitoring
    _gpsHealthCheckTimer?.cancel();
    _gpsHealthCheckTimer = null;
  }

  /// Monitor GPS health and restart if no updates received
  void _startGpsHealthCheck() {
    _lastGpsUpdate = DateTime.now();
    
    _gpsHealthCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!isRunning.value) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final timeSinceLastUpdate = _lastGpsUpdate != null 
          ? now.difference(_lastGpsUpdate!).inSeconds 
          : 999;
      
      if (timeSinceLastUpdate > 12) { // No GPS for 12+ seconds
        print('⚠️ GPS health check: No updates for ${timeSinceLastUpdate}s');
        
        if (_gpsRestartCount < 5) {
          _gpsRestartCount++;
          print('🔄 GPS health check triggered restart (attempt $_gpsRestartCount)');
          _startLocationTracking();
        } else {
          print('⚠️ GPS health check: Maximum restart attempts reached');
          timer.cancel();
          Get.snackbar(
            'GPS Connection Issue',
            'GPS signal lost. Try moving to an open area.',
            duration: const Duration(seconds: 4),
          );
        }
      } else {
        print('✅ GPS health check: Signal healthy (${timeSinceLastUpdate}s ago)');
      }
    });
  }

  void _startDurationTimer() {
    // Cancel any existing timer first
    _durationTimer?.cancel();
    
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_runStartTime != null && isRunning.value) {
        runDuration.value = DateTime.now().difference(_runStartTime!);
      }
    });
  }

  void _onLocationUpdate(geo.Position position) {
    if (!isRunning.value) {
      print('⏸️ Not running, ignoring GPS update');
      return;
    }
    
    // Reset GPS restart counter on successful location update
    _gpsRestartCount = 0;
    _lastGpsUpdate = DateTime.now(); // Update last GPS timestamp
    
    print('📍 Raw GPS update: ${position.latitude}, ${position.longitude} | Accuracy: ${position.accuracy}m | Speed: ${position.speed}m/s');
    
    // Filter out inaccurate readings
    if (position.accuracy > _maxAccuracy) {
      print('🚫 Filtering out inaccurate position: ${position.accuracy}m > ${_maxAccuracy}m');
      return;
    }
    
    // Filter out positions that are too close to last position
    if (_lastPosition != null) {
      double distance = _locationService.calculateDistance(_lastPosition!, position);
      
      print('📏 Distance from last position: ${distance.toStringAsFixed(2)}m');
      
      if (distance < _minDistanceThreshold) {
        print('⏭️ Too close to last position (${distance.toStringAsFixed(2)}m < ${_minDistanceThreshold}m), skipping');
        return; // Too close, skip this update
      }
      
      // Update total distance
      double oldDistance = totalDistance.value;
      totalDistance.value += distance;
      print('🏃 Total distance updated: ${oldDistance.toStringAsFixed(2)}m → ${totalDistance.value.toStringAsFixed(2)}m (+${distance.toStringAsFixed(2)}m)');
    }
    
    // Convert to LatLngPoint and add to tracking
    LatLngPoint point = _locationService.positionToLatLngPoint(position);
    print('🎯 Converting position to LatLngPoint: ${point.latitude}, ${point.longitude}');
    _addTrackingPoint(point);
    
    _lastPosition = position;
  }

  void _addTrackingPoint(LatLngPoint point) {
    _rawPathPoints.add(point);
    currentPath.add(point);
    
    print('🗺️ Added tracking point ${currentPath.length}: ${point.latitude}, ${point.longitude}');
    
    // Update live path on map
    _updateLivePathOnMap();
    
    // Check for auto-close dotted line (if we have a starting point and current path)
    _updateDottedCloseLineIfNeeded();
    
    // Limit visible path for performance (keep last 500 points)
    if (currentPath.length > 500) {
      currentPath.removeAt(0);
    }
  }
  
  void _updateLivePathOnMap() async {
    if (_runMap == null) {
      print('⚠️ Cannot update path: _runMap is null');
      return;
    }
    
    if (currentPath.length < 2) {
      print('⚠️ Not enough points for path: ${currentPath.length}');
      return;
    }
    
    print('🗺️ Updating live path with ${currentPath.length} points...');
    
    try {
      // Remove existing path line if it exists
      if (_pathLineLayerId != null) {
        try {
          await _runMap!.style.removeStyleLayer(_pathLineLayerId!);
          await _runMap!.style.removeStyleSource('run-path-source');
          print('🔄 Removed existing path layer');
        } catch (e) {
          print('ℹ️ Layer cleanup error (expected for first draw): $e');
        }
      }
      
      // Add new path line
      _pathLineLayerId = 'run-path-line';
      
      // Create GeoJSON source for the path
      List<List<num>> coordinates = currentPath.map((point) => [point.longitude, point.latitude]).toList();
      String geoJsonData = '''
      {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": $coordinates
        }
      }
      ''';
      
      print('📡 Adding GeoJSON source with ${coordinates.length} coordinates');
      
      await _runMap!.style.addSource(GeoJsonSource(
        id: 'run-path-source',
        data: geoJsonData,
      ));
      
      print('🎨 Adding line layer with color: ${selectedPathColor.value}');
      
      // Add line layer for the path
      await _runMap!.style.addLayer(LineLayer(
        id: _pathLineLayerId!,
        sourceId: 'run-path-source',
        lineColor: _colorToInt(selectedPathColor.value),
        lineWidth: 4.0,
        lineOpacity: 0.8,
      ));
      
      print('✅ Live path updated successfully on map with ${currentPath.length} points');
    } catch (e) {
      print('❌ Error updating live path on map: $e');
      print('Error type: ${e.runtimeType}');
    }
  }
  
  int _colorToInt(Color color) {
    return color.value;
  }
  
  void _updateDottedCloseLineIfNeeded() async {
    if (_runMap == null || currentPath.length < 10) return; // Need at least 10 points for meaningful territory
    
    LatLngPoint startPoint = currentPath.first;
    LatLngPoint currentPoint = currentPath.last;
    await _showDottedCloseLine(startPoint, currentPoint);
  }
  
  Future<void> _showDottedCloseLine(LatLngPoint start, LatLngPoint end) async {
    if (_runMap == null) return;
    
    try {
      // Remove existing dotted line if it exists
      await _removeDottedCloseLine();
      
      _dottedLineLayerId = 'run-dotted-close-line';
      
      // Create GeoJSON for dotted line from current position to start
      String geoJsonData = '''
      {
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": [[${end.longitude}, ${end.latitude}], [${start.longitude}, ${start.latitude}]]
        }
      }
      ''';
      
      await _runMap!.style.addSource(GeoJsonSource(
        id: 'run-dotted-source',
        data: geoJsonData,
      ));
      
      // Add dotted line layer
      await _runMap!.style.addLayer(LineLayer(
        id: _dottedLineLayerId!,
        sourceId: 'run-dotted-source',
        lineColor: _colorToInt(selectedPathColor.value),
        lineWidth: 3.0,
        lineOpacity: 0.6,
        lineDasharray: [2.0, 4.0], // Creates dotted effect
      ));
      
      double distance = _calculateDistanceBetweenPoints(start, end);
      print('Dotted close line shown - distance: ${distance.toStringAsFixed(1)}m');
    } catch (e) {
      print('Error showing dotted close line: $e');
    }
  }
  
  Future<void> _removeDottedCloseLine() async {
    if (_runMap == null || _dottedLineLayerId == null) return;
    
    try {
      await _runMap!.style.removeStyleLayer(_dottedLineLayerId!);
      await _runMap!.style.removeStyleSource('run-dotted-source');
      _dottedLineLayerId = null;
    } catch (e) {
      // Layer might not exist, ignore error
    }
  }
  
  double _calculateDistanceBetweenPoints(LatLngPoint point1, LatLngPoint point2) {
    // Use the Haversine formula for distance calculation
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  void _processTerritoryCreation() async {
    print('🚀 _processTerritoryCreation() method entered');
    
    // Prevent duplicate territory creation
    if (_isProcessingTerritory) {
      print('⚠️ Territory creation already in progress, skipping duplicate call');
      return;
    }
    
    print('🗺️ Starting territory creation process...');
    print('🗺️ Raw path points count: ${_rawPathPoints.length}');
    print('🗺️ Total distance: ${totalDistance.value.toStringAsFixed(2)}m');
    
    _isProcessingTerritory = true;
    
    if (_rawPathPoints.isEmpty) {
      print('❌ No GPS points available for territory creation');
      Get.snackbar(
        'No GPS Data',
        'No GPS tracking data available. Please try running again.',
        duration: const Duration(seconds: 3),
      );
      _isProcessingTerritory = false;
      Get.offAllNamed('/home'); // Navigate to main app view
      _resetRun();
      return;
    }
    
    if (_rawPathPoints.length < 3) {
      print('❌ Insufficient GPS points: ${_rawPathPoints.length} < 3');
      Get.snackbar(
        'Insufficient Data',
        'Not enough GPS points to create territory',
        duration: const Duration(seconds: 3),
      );
      _isProcessingTerritory = false;
      Get.offAllNamed('/home'); // Navigate to main app view
      _resetRun();
      return;
    }
    print('🗺️ Processing territory creation with ${_rawPathPoints.length} points');
    
    
    // Check authentication status
    final isAuthenticated = _databaseService.isAuthenticated;
    final currentUserId = _databaseService.currentUserId;
    print('🔐 Authentication status: $isAuthenticated, User ID: $currentUserId');
    
    if (!isAuthenticated) {
      print('❌ User not authenticated - territory upload will fail');
      Get.snackbar(
        'Authentication Error',
        'Please sign in to save territories',
        duration: const Duration(seconds: 3),
      );
      _isProcessingTerritory = false;
      Get.offAllNamed('/home'); // Navigate to main app view
      _resetRun();
      return;
    }
    
    // Detect if we have a closed loop or need to auto-close
    print('🗺️ Creating territory polygon...');
    List<LatLngPoint> territoryPoints = _createTerritoryPolygon();
    
    print('🗺️ Territory polygon created with ${territoryPoints.length} points');
    
    if (territoryPoints.length >= 3) {
      // Calculate territory area
      print('📏 Calculating territory area...');
      double area = _calculateTerritoryArea(territoryPoints);
      print('📏 Calculated area: ${area.toStringAsFixed(6)} m²');
      
      print('✅ Territory area: ${area.toStringAsFixed(2)} m²');
      
      // Validate polygon is closed
      if (!_arePointsEqual(territoryPoints.first, territoryPoints.last)) {
        print('❌ Polygon is not closed - adding closing point');
        territoryPoints.add(territoryPoints.first);
      }
      
      print('✅ Polygon validation: ${territoryPoints.length} points, closed: ${_arePointsEqual(territoryPoints.first, territoryPoints.last)}');
      
      // Calculate territory center
      LatLngPoint center = _calculateCenter(territoryPoints);
      
      // Use actual user ID if available
      String ownerId = _territoryService.currentUserId ?? 'current_user';
      
      // Generate a proper UUID for the territory
      String territoryId = _uuid.v4();
      
      // Validate territory data before creation
      print('🗺️ Validating territory data before creation...');
      print('🗺️ - Points count: ${territoryPoints.length}');
      print('🗺️ - Area: $area m²');
      print('🗺️ - Center: ${center.latitude}, ${center.longitude}');
      
      // Ensure all points have valid coordinates
      for (int i = 0; i < territoryPoints.length; i++) {
        final point = territoryPoints[i];
        if (point.latitude.isNaN || point.longitude.isNaN || 
            point.latitude.isInfinite || point.longitude.isInfinite) {
          print('❌ Invalid coordinates at point $i: ${point.latitude}, ${point.longitude}');
          throw Exception('Invalid coordinates detected in territory points');
        }
      }
      
      // Get current user's color for the new territory
      String ownerColor = '#3B82F6'; // Default blue
      try {
        final userPrefs = Get.find<UserPreferencesService>();
        ownerColor = '#${userPrefs.userColor.value.value.toRadixString(16).padLeft(8, '0')}';
      } catch (e) {
        print('⚠️ Could not get user color, using default: $e');
      }
      
      // Create Territory object with owner color
      Territory newTerritory = Territory(
        id: territoryId,
        ownerId: ownerId,
        boundaryPoints: territoryPoints,
        area: area,
        createdAt: DateTime.now(),
        center: center,
        ownerColor: ownerColor,
      );
      
      
      // Verify polygon closure
      print('🗺️ Polygon closure verification:');
      print('🗺️ - First point: ${territoryPoints.first.latitude}, ${territoryPoints.first.longitude}');
      print('🗺️ - Last point: ${territoryPoints.last.latitude}, ${territoryPoints.last.longitude}');
      print('🗺️ - Are equal: ${_arePointsEqual(territoryPoints.first, territoryPoints.last)}');

      // Insert exactly one new territory for the FULL run polygon
      print('📤 Uploading new territory (single insert) to Supabase...');
      print('📤 Territory details:');
      print('📤 - ID: ${newTerritory.id}');
      print('📤 - Owner ID: ${newTerritory.ownerId}');
      print('📤 - Area: ${newTerritory.area} m²');
      print('📤 - Boundary points: ${newTerritory.boundaryPoints.length}');
      print('📤 - Center: ${newTerritory.center.latitude}, ${newTerritory.center.longitude}');
      
      // Set uploading state
      isUploadingTerritory.value = true;
      
      try {
        final uploadResult = await _databaseService.uploadTerritory(newTerritory);
        print('✅ Territory uploaded to Supabase successfully: $uploadResult');
      } catch (e) {
        print('❌ Failed to upload territory to Supabase: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error details: $e');
        
        // Show more specific error message
        String errorMessage = 'Territory upload failed';
        if (e.toString().contains('Invalid polygon')) {
          errorMessage = 'Invalid territory shape - please try running again';
        } else if (e.toString().contains('below minimum')) {
          errorMessage = 'Territory too small - run a longer route';
        } else if (e.toString().contains('authentication')) {
          errorMessage = 'Authentication error - please sign in again';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error - check your connection';
        }
        
        Get.snackbar(
          'Upload Failed',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        
        // Even if upload fails, try to display the territory locally
        print('🔄 Attempting to display territory locally despite upload failure...');
        try {
          await _createTerritoryArea(territoryPoints);
          print('✅ Territory displayed locally despite upload failure');
        } catch (e) {
          print('❌ Failed to display territory locally: $e');
        }
        
        // Clear uploading state
        isUploadingTerritory.value = false;
        _isProcessingTerritory = false;
        return; // Don't continue if upload fails
      }
      
      // Add territory to local service for immediate UI update
      print('📤 Adding territory to local service...');
      await _territoryService.addUserTerritory(newTerritory);
      print('✅ Territory added to userTerritories list and saved locally');
      
      // Update user statistics after territory creation using current run data
      // Do this before or alongside recompute so run stats are persisted
      try {
        final runDistanceMeters = totalDistance.value; // meters
        final runDurationSeconds = runDuration.value.inSeconds; // seconds
        print('📊 Updating user statistics: distance=${runDistanceMeters.toStringAsFixed(2)}m, duration=${runDurationSeconds}s');

        final currentUserId = _territoryService.currentUserId ?? _databaseService.currentUserId;
        if (currentUserId != null) {
          await _databaseService.updateUserStatistics(
            userId: currentUserId,
            runDistance: runDistanceMeters,
            runDuration: runDurationSeconds,
            territoryArea: area,
            territoryConquered: false,
          );
          print('✅ User statistics updated with current run');
        } else {
          print('⚠️ No current user ID found for statistics update');
        }
      } catch (e) {
        print('⚠️ Warning: Failed to update user statistics with current run: $e');
      }

      // Force server-side recomputation to ensure consistency (kept after explicit update)
      print('📊 Recomputing user statistics after territory creation...');
      try {
        await _databaseService.recomputeUserStatistics(newTerritory.ownerId);
        print('✅ User statistics recomputed successfully');
      } catch (e) {
        print('⚠️ Warning: Failed to recompute user statistics: $e');
        // Don't fail the territory creation if stats update fails
      }
      
      // SINGLE SOURCE OF TRUTH: Refresh territory data from Supabase ONCE
      // This prevents duplicate refreshes and ensures data consistency
      print('🔄 SINGLE REFRESH: Updating territory data from Supabase...');
      await _territoryService.refreshTerritoryData();
      
      print('✅ Territory data refreshed from Supabase (single update)');
      
      // Refresh bottom sheet to show updated territory history
      try {
        TerritoryBottomSheet.refresh();
        print('✅ Bottom sheet refreshed with new territory data');
      } catch (e) {
        print('⚠️ Could not refresh bottom sheet: $e');
      }
      
      // Create and display the territory area on current map
      print('🎨 Creating territory visualization with ${territoryPoints.length} points');
      print('🎨 Territory color: ${selectedPathColor.value}');
      print('🎨 Territory color hex: #${selectedPathColor.value.value.toRadixString(16).padLeft(8, '0')}');
      
      // Create territory visualization
      try {
        await _createTerritoryArea(territoryPoints);
        print('🎨 Territory visualization completed successfully');
      } catch (e) {
        print('❌ Main territory visualization failed: $e');
        print('🎨 Attempting fallback visualization...');
        await _createFallbackTerritoryVisualization(territoryPoints);
      }
      
      Get.snackbar(
        'Territory Created!',
        'You claimed ${area.toStringAsFixed(0)} m² of territory!\nIt will appear on your main map.',
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Territory Creation Failed',
        'Unable to create a valid territory area from your path',
        duration: const Duration(seconds: 3),
      );
    }
    
          // Clear uploading state
      isUploadingTerritory.value = false;
      
      // Reset the processing flag
      _isProcessingTerritory = false;
      print('🗺️ Territory creation process completed');
      
      // Auto-navigate to main map after successful territory creation
      Future.delayed(const Duration(seconds: 1), () {
        if (runState.value == RunState.finished) {
          print('🔄 Auto-navigating to main map after territory creation...');
          goToMainMap();
        }
      });
  }

  List<LatLngPoint> _createTerritoryPolygon() {
    if (_rawPathPoints.length < 3) return [];
    
    print('🔧 Creating ROBUST territory polygon from ${_rawPathPoints.length} raw points');
    
    try {
      // Step 1: Clean and simplify the path points
      List<LatLngPoint> cleanedPoints = _cleanAndSimplifyPath(_rawPathPoints);
      print('🔧 Cleaned points: ${cleanedPoints.length}');
      
      if (cleanedPoints.length < 3) {
        print('❌ Insufficient cleaned points, trying fallback circular territory');
        List<LatLngPoint> fallback = _createFallbackCircularTerritory();
        if (fallback.isNotEmpty) return fallback;
        
        print('❌ Circular territory failed, trying rectangular territory');
        return _createFallbackRectangularTerritory();
      }
      
      // Step 2: Create a convex hull if we have enough points
      List<LatLngPoint> polygonPoints = _createConvexHull(cleanedPoints);
      print('🔧 Convex hull created with ${polygonPoints.length} points');
      
      if (polygonPoints.length < 3) {
        print('❌ Convex hull failed, trying fallback circular territory');
        List<LatLngPoint> fallback = _createFallbackCircularTerritory();
        if (fallback.isNotEmpty) return fallback;
        
        print('❌ Circular territory failed, trying rectangular territory');
        return _createFallbackRectangularTerritory();
      }
      
      // Step 3: Ensure the polygon is closed and valid for PostGIS
      polygonPoints = _ensureValidPolygon(polygonPoints);
      print('🔧 Final valid polygon: ${polygonPoints.length} points');
      
      if (polygonPoints.isEmpty) {
        print('❌ Polygon validation failed, trying fallback circular territory');
        List<LatLngPoint> fallback = _createFallbackCircularTerritory();
        if (fallback.isNotEmpty) return fallback;
        
        print('❌ Circular territory failed, trying rectangular territory');
        return _createFallbackRectangularTerritory();
      }
      
      return polygonPoints;
    } catch (e) {
      print('❌ Error in robust polygon creation: $e');
      print('🔧 Trying fallback circular territory...');
      List<LatLngPoint> fallback = _createFallbackCircularTerritory();
      if (fallback.isNotEmpty) return fallback;
      
      print('❌ Circular territory failed, trying rectangular territory');
      return _createFallbackRectangularTerritory();
    }
  }
  
  /// Clean and simplify path points to remove duplicates and noise
  List<LatLngPoint> _cleanAndSimplifyPath(List<LatLngPoint> rawPoints) {
    if (rawPoints.length < 3) return rawPoints;
    
    List<LatLngPoint> cleaned = [];
    cleaned.add(rawPoints.first); // Always include first point
    
    // Remove duplicate points and points too close together
    const double minDistance = 0.5; // 0.5 meters minimum distance between points
    
    for (int i = 1; i < rawPoints.length; i++) {
      LatLngPoint current = rawPoints[i];
      LatLngPoint lastAdded = cleaned.last;
      
      double distance = _calculateDistanceBetweenPoints(current, lastAdded);
      if (distance >= minDistance) {
        cleaned.add(current);
      }
    }
    
    // Always include last point if it's different from the last added
    if (cleaned.isNotEmpty && 
        _calculateDistanceBetweenPoints(cleaned.last, rawPoints.last) >= minDistance) {
      cleaned.add(rawPoints.last);
    }
    
    print('🔧 Path cleaned: ${rawPoints.length} -> ${cleaned.length} points');
    return cleaned;
  }
  
  /// Create a convex hull from the given points (ensures valid polygon)
  List<LatLngPoint> _createConvexHull(List<LatLngPoint> points) {
    if (points.length < 3) return points;
    
    // Graham's scan algorithm for convex hull
    List<LatLngPoint> hull = [];
    
    // Find the point with lowest y-coordinate (and leftmost if tied)
    LatLngPoint start = points.reduce((a, b) => 
      a.latitude < b.latitude ? a : (a.latitude == b.latitude && a.longitude < b.longitude ? a : b)
    );
    
    // Sort points by polar angle with respect to start point
    List<LatLngPoint> sorted = List.from(points);
    sorted.sort((a, b) {
      if (a == start) return -1;
      if (b == start) return 1;
      
      double angleA = _calculateAngle(start, a);
      double angleB = _calculateAngle(start, b);
      
      if (angleA != angleB) return angleA.compareTo(angleB);
      
      // If angles are equal, sort by distance
      double distA = _calculateDistanceBetweenPoints(start, a);
      double distB = _calculateDistanceBetweenPoints(start, b);
      return distB.compareTo(distA); // Reverse order for proper hull
    });
    
    // Build convex hull
    hull.add(start);
    if (sorted.length > 1) hull.add(sorted[1]);
    
    for (int i = 2; i < sorted.length; i++) {
      while (hull.length > 1 && _crossProduct(hull[hull.length - 2], hull[hull.length - 1], sorted[i]) <= 0) {
        hull.removeLast();
      }
      hull.add(sorted[i]);
    }
    
    print('🔧 Convex hull created with ${hull.length} points');
    return hull;
  }
  
  /// Calculate angle between two points relative to horizontal
  double _calculateAngle(LatLngPoint from, LatLngPoint to) {
    return math.atan2(to.latitude - from.latitude, to.longitude - from.longitude);
  }
  
  /// Calculate cross product for convex hull algorithm
  double _crossProduct(LatLngPoint a, LatLngPoint b, LatLngPoint c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) - 
           (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }
  
  /// Ensure the polygon is valid and closed for PostGIS
  List<LatLngPoint> _ensureValidPolygon(List<LatLngPoint> points) {
    if (points.length < 3) return points;
    
    List<LatLngPoint> validPolygon = List.from(points);
    
    // Ensure first and last points are exactly the same (PostGIS requirement)
    LatLngPoint firstPoint = validPolygon.first;
    LatLngPoint lastPoint = validPolygon.last;
    
    // Use exact coordinate comparison for PostGIS compatibility
    if (firstPoint.latitude != lastPoint.latitude || firstPoint.longitude != lastPoint.longitude) {
      // Create exact copy of first point
      validPolygon.add(LatLngPoint(
        latitude: firstPoint.latitude,
        longitude: firstPoint.longitude,
        timestamp: firstPoint.timestamp,
      ));
      print('🔧 Added exact closing point for PostGIS compatibility');
    }
    
    // Validate polygon has at least 3 points
    if (validPolygon.length < 3) {
      print('❌ Invalid polygon: insufficient points after processing');
      return [];
    }
    
    print('🔧 Valid polygon ensured: ${validPolygon.length} points');
    return validPolygon;
  }
  
  /// Create a fallback circular territory if polygon creation fails
  List<LatLngPoint> _createFallbackCircularTerritory() {
    print('🔧 Creating fallback circular territory...');
    
    if (_rawPathPoints.isEmpty) return [];
    
    // Calculate center from all points
    double centerLat = 0.0;
    double centerLng = 0.0;
    
    for (var point in _rawPathPoints) {
      centerLat += point.latitude;
      centerLng += point.longitude;
    }
    
    centerLat /= _rawPathPoints.length;
    centerLng /= _rawPathPoints.length;
    
    // Calculate radius based on the maximum distance from center
    double maxRadius = 0.0;
    for (var point in _rawPathPoints) {
      double distance = _calculateDistanceBetweenPoints(
        LatLngPoint(latitude: centerLat, longitude: centerLng, timestamp: DateTime.now()),
        point
      );
      if (distance > maxRadius) maxRadius = distance;
    }
    
    // Ensure minimum radius for valid territory
    maxRadius = math.max(maxRadius, 5.0); // At least 5 meters
    
    // Create a circular polygon with 16 points
    List<LatLngPoint> circlePoints = [];
    const int numPoints = 16;
    
    for (int i = 0; i <= numPoints; i++) {
      double angle = (2 * math.pi * i) / numPoints;
      double lat = centerLat + (maxRadius / 111320.0) * math.cos(angle); // Convert meters to degrees
      double lng = centerLng + (maxRadius / (111320.0 * math.cos(centerLat * math.pi / 180))) * math.sin(angle);
      
      circlePoints.add(LatLngPoint(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
      ));
    }
    
    print('🔧 Fallback circular territory created with ${circlePoints.length} points');
    print('🔧 Center: $centerLat, $centerLng, Radius: ${maxRadius.toStringAsFixed(1)}m');
    
    return circlePoints;
  }
  
  /// Create a fallback rectangular territory if circular fails
  List<LatLngPoint> _createFallbackRectangularTerritory() {
    print('🔧 Creating fallback rectangular territory...');
    
    if (_rawPathPoints.isEmpty) return [];
    
    // Find bounding box
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (var point in _rawPathPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    // Add padding to ensure minimum size
    double latPadding = 0.0001; // About 11 meters
    double lngPadding = 0.0001; // About 11 meters
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;
    
    // Create rectangular polygon (5 points: 4 corners + closing point)
    List<LatLngPoint> rectPoints = [
      LatLngPoint(latitude: minLat, longitude: minLng, timestamp: DateTime.now()),
      LatLngPoint(latitude: minLat, longitude: maxLng, timestamp: DateTime.now()),
      LatLngPoint(latitude: maxLat, longitude: maxLng, timestamp: DateTime.now()),
      LatLngPoint(latitude: maxLat, longitude: minLng, timestamp: DateTime.now()),
      LatLngPoint(latitude: minLat, longitude: minLng, timestamp: DateTime.now()), // Close the rectangle
    ];
    
    print('🔧 Fallback rectangular territory created with ${rectPoints.length} points');
    print('🔧 Bounds: ${minLat.toStringAsFixed(6)} to ${maxLat.toStringAsFixed(6)}, ${minLng.toStringAsFixed(6)} to ${maxLng.toStringAsFixed(6)}');
    
    return rectPoints;
  }
  
  Future<void> _createTerritoryArea(List<LatLngPoint> territoryPoints) async {
    if (_runMap == null || territoryPoints.length < 3) return;
    
    print('🎨 Starting territory visualization...');
    print('🎨 Map available: ${_runMap != null}');
    print('🎨 Points count: ${territoryPoints.length}');
    print('🎨 Selected color: ${selectedPathColor.value}');
    print('🎨 Color int value: ${_colorToInt(selectedPathColor.value)}');
    
    try {
      // Remove existing territory layers if they exist
      await _removeExistingTerritoryLayers();
      
      // Convert points to coordinates for polygon
      List<List<double>> coordinates = territoryPoints.map((point) => 
        [point.longitude, point.latitude]
      ).toList();
      
      print('🎨 Converted coordinates: ${coordinates.length} points');
      
      // Ensure polygon is closed for GeoJSON
      if (coordinates.isNotEmpty && 
          (coordinates.first[0] != coordinates.last[0] || 
           coordinates.first[1] != coordinates.last[1])) {
        coordinates.add(coordinates.first);
        print('🎨 Added closing coordinate to make polygon closed');
      }
      
      // Create proper GeoJSON format
      String coordinatesString = coordinates.map((coord) => '[${coord[0]}, ${coord[1]}]').join(',');
      String geoJsonData = '''
      {
        "type": "Feature",
        "geometry": {
          "type": "Polygon",
          "coordinates": [[$coordinatesString]]
        }
      }
      ''';
      
      print('🎨 GeoJSON data created: ${geoJsonData.length} characters');
      print('🎨 GeoJSON content: $geoJsonData');
      
      // Add territory area source
      print('🎨 Adding GeoJSON source...');
      await _runMap!.style.addSource(GeoJsonSource(
        id: 'territory-area-source',
        data: geoJsonData,
      ));
      print('✅ GeoJSON source added');
      
      // Add filled territory area layer
      print('🎨 Adding fill layer...');
      await _runMap!.style.addLayer(FillLayer(
        id: 'territory-area-fill',
        sourceId: 'territory-area-source',
        fillColor: _colorToInt(selectedPathColor.value),
        fillOpacity: 0.6, // More visible fill
      ));
      print('✅ Fill layer added');
      
      // Add territory border layer
      print('🎨 Adding border layer...');
      await _runMap!.style.addLayer(LineLayer(
        id: 'territory-area-border',
        sourceId: 'territory-area-source',
        lineColor: _colorToInt(selectedPathColor.value),
        lineWidth: 3.0, // Thicker border
        lineOpacity: 1.0, // Fully opaque border
      ));
      print('✅ Border layer added');
      
      print('✅ Territory area created and displayed on map');
    } catch (e) {
      print('❌ Error creating territory area: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
      print('📍 Territory points: ${territoryPoints.length}');
      if (territoryPoints.isNotEmpty) {
        print('📍 First point: ${territoryPoints.first.latitude}, ${territoryPoints.first.longitude}');
        print('📍 Last point: ${territoryPoints.last.latitude}, ${territoryPoints.last.longitude}');
      }
    }
  }
  
  Future<void> _removeExistingTerritoryLayers() async {
    if (_runMap == null) return;
    
    try {
      // Remove existing territory layers
      await _runMap!.style.removeStyleLayer('territory-area-fill');
      await _runMap!.style.removeStyleLayer('territory-area-border');
      await _runMap!.style.removeStyleSource('territory-area-source');
      print('✅ Removed existing territory layers');
    } catch (e) {
      // Layers might not exist, ignore error
      print('ℹ️ No existing territory layers to remove');
    }
  }
  
  /// Create a simple fallback territory visualization using circles
  Future<void> _createFallbackTerritoryVisualization(List<LatLngPoint> territoryPoints) async {
    if (_runMap == null || territoryPoints.length < 3) return;
    
    print('🎨 Creating fallback territory visualization...');
    
    try {
      // Create a simple circle visualization at the center
      LatLngPoint center = _calculateCenter(territoryPoints);
      double radius = 20.0; // 20 meter radius
      
      // Add circle source
      String circleGeoJson = '''
      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [${center.longitude}, ${center.latitude}]
        }
      }
      ''';
      
      await _runMap!.style.addSource(GeoJsonSource(
        id: 'territory-fallback-source',
        data: circleGeoJson,
      ));
      
      // Add circle layer
      await _runMap!.style.addLayer(CircleLayer(
        id: 'territory-fallback-circle',
        sourceId: 'territory-fallback-source',
        circleRadius: radius,
        circleColor: _colorToInt(selectedPathColor.value),
        circleOpacity: 0.7,
      ));
      
      print('✅ Fallback territory visualization created');
    } catch (e) {
      print('❌ Error creating fallback visualization: $e');
    }
  }

  LatLngPoint _calculateCenter(List<LatLngPoint> points) {
    if (points.isEmpty) {
      return LatLngPoint(
      latitude: 0, 
      longitude: 0, 
      timestamp: DateTime.now(),
    );
    }
    
    double latSum = 0;
    double lngSum = 0;
    
    for (LatLngPoint point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    
    return LatLngPoint(
      latitude: latSum / points.length,
      longitude: lngSum / points.length,
      timestamp: DateTime.now(),
    );
  }
  
  double _calculateTerritoryArea(List<LatLngPoint> points) {
    if (points.length < 3) return 0;
    
    // Use shoelace formula for polygon area calculation
    double area = 0;
    int n = points.length;
    
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += points[i].longitude * points[j].latitude;
      area -= points[j].longitude * points[i].latitude;
    }
    
    area = area.abs() / 2.0;
    
    // Convert from degrees to square meters (more accurate for small areas)
    double avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    
    // More precise conversion factors
    double metersPerDegreeLat = 111320; // Constant for latitude
    double metersPerDegreeLng = 111320 * math.cos(avgLat * math.pi / 180); // Varies with latitude
    
    // For small areas, use more precise calculation
    double areaInSquareMeters = area * metersPerDegreeLat * metersPerDegreeLng;
    
    // If the area is still too small, try using the bounding box method as fallback
    if (areaInSquareMeters < 1.0) {
      double minLat = points.map((p) => p.latitude).reduce(math.min);
      double maxLat = points.map((p) => p.latitude).reduce(math.max);
      double minLng = points.map((p) => p.longitude).reduce(math.min);
      double maxLng = points.map((p) => p.longitude).reduce(math.max);
      
      double latDiff = (maxLat - minLat) * metersPerDegreeLat;
      double lngDiff = (maxLng - minLng) * metersPerDegreeLng;
      
      areaInSquareMeters = latDiff * lngDiff;
      print('📏 Using bounding box fallback: ${areaInSquareMeters.toStringAsFixed(2)} m²');
    }
    
    print('📏 Area calculation: raw=${area.toStringAsFixed(6)}, lat=${avgLat.toStringAsFixed(4)}, metersPerDegreeLat=${metersPerDegreeLat.toStringAsFixed(0)}, metersPerDegreeLng=${metersPerDegreeLng.toStringAsFixed(0)}, final=${areaInSquareMeters.toStringAsFixed(2)} m²');
    
    return areaInSquareMeters;
  }
  
  bool _arePointsEqual(LatLngPoint point1, LatLngPoint point2, {double tolerance = 0.0001}) {
    double latDiff = (point1.latitude - point2.latitude).abs();
    double lngDiff = (point1.longitude - point2.longitude).abs();
    
    bool areEqual = latDiff < tolerance && lngDiff < tolerance;
    
    if (!areEqual) {
      print('🔍 Point comparison failed:');
      print('🔍 - Point1: ${point1.latitude}, ${point1.longitude}');
      print('🔍 - Point2: ${point2.latitude}, ${point2.longitude}');
      print('🔍 - Lat diff: ${latDiff.toStringAsFixed(8)} (tolerance: $tolerance)');
      print('🔍 - Lng diff: ${lngDiff.toStringAsFixed(8)} (tolerance: $tolerance)');
    }
    
    return areEqual;
  }

  // Getters for UI
  String get formattedDistance {
    if (totalDistance.value < 1000) {
      return '${totalDistance.value.toStringAsFixed(0)} m';
    } else {
      return '${(totalDistance.value / 1000).toStringAsFixed(2)} km';
    }
  }

  String get formattedDuration {
    int hours = runDuration.value.inHours;
    int minutes = runDuration.value.inMinutes % 60;
    int seconds = runDuration.value.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get averageSpeed {
    if (runDuration.value.inSeconds == 0) return '0.0 km/h';
    double speedKmh = (totalDistance.value / 1000) / (runDuration.value.inSeconds / 3600);
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  // Additional methods for run controls - COMMENTED OUT
  /*
  void discardRun() {
    if (runState.value == RunState.idle) return;
    
    _resetRun();
  }
  */

  /// Navigate to main map (territory data already refreshed during creation)
  void goToMainMap() async {
    print('🗺️ Navigating to main map...');
    
    // Wait for territory upload to complete if it's still in progress
    if (isUploadingTerritory.value) {
      print('⏳ Waiting for territory upload to complete...');
      return; // Don't navigate yet
    }
    
    try {
  // Attempt daily challenge award (new logic). Navigation always proceeds after check.
  await _attemptDailyChallengeAward();
  _navigateToMainMapAfterAnimation();
      
    } catch (e) {
      print('❌ Error during navigation: $e');
      // Still navigate even if there's an error
      _navigateToMainMapAfterAnimation();
    }
  }
  
  /// Attempt daily challenge award (server-side single-award safeguard)
  Future<void> _attemptDailyChallengeAward() async {
    try {
      final runDurationMinutes = runDuration.value.inMinutes;
      final runDistanceMeters = totalDistance.value;
      if (!Get.isRegistered<DatabaseService>()) return;
      final db = Get.find<DatabaseService>();
      final result = await db.createRunAndMaybeAward(
        durationMinutes: runDurationMinutes,
        distanceMeters: runDistanceMeters,
      );
      DailyChallengeService? svc;
      if (Get.isRegistered<DailyChallengeService>()) {
        svc = Get.find<DailyChallengeService>();
        svc.applyRunResult(result);
      }
      final awarded = result?['awarded'] == true;
      if (awarded) {
        // Avoid manual coin increment; rely on server & subsequent profile refresh elsewhere
        print('✅ Daily challenge coins awarded (server authoritative).');
      } else {
        print('ℹ️ Daily challenge not yet completed.');
      }
      // Optionally force refresh to sync coins/progress
      svc?.refreshFromServer(force: true);
    } catch (e) {
      print('❌ Error attempting daily challenge award: $e');
    }
  }

  /// Navigate to main map after animation completes
  void _navigateToMainMapAfterAnimation() {
    try {
      // Territory data is already refreshed during territory creation
      // No need to refresh again - this prevents duplicate Supabase updates
      print('ℹ️ Skipping territory refresh - data already updated during creation');
      
      // Pop all pages until main navigation is visible
      Get.offAllNamed('/home'); // Navigate to main app view
      
      // Reset run state
      _resetRun();
      print('✅ Successfully navigated to main map after animation');
    } catch (e) {
      print('❌ Error during navigation: $e');
      // Still navigate even if there's an error
      Get.offAllNamed('/home'); // Navigate to main app view
      _resetRun();
    }
  }

  void _resetRun() {
    runState.value = RunState.idle;
    isRunning.value = false;
    isPaused.value = false;
    isStartingRun.value = false; // Clear loading state
    isUploadingTerritory.value = false; // Clear territory upload state
    totalDistance.value = 0.0;
    runDuration.value = const Duration();
    currentPath.clear();
    currentRunSession.value = null;
    
    // Clear all tracking data
    _rawPathPoints.clear();
    _lastPosition = null;
    
    // Stop all timers and tracking
    _stopLocationTracking();
    _durationTimer?.cancel();
    _durationTimer = null;
    _runStartTime = null;
    
    // Clear map elements
    _clearPathFromMap();
  }
  
  void _clearPathFromMap() async {
    if (_runMap == null) return;
    
    try {
      // Clear main path line
      if (_pathLineLayerId != null) {
        await _runMap!.style.removeStyleLayer(_pathLineLayerId!);
        await _runMap!.style.removeStyleSource('run-path-source');
        _pathLineLayerId = null;
      }
      
      // Clear dotted close line
      await _removeDottedCloseLine();
      
      // Clear territory area if it exists
      try {
        await _runMap!.style.removeStyleLayer('territory-area-fill');
        await _runMap!.style.removeStyleLayer('territory-area-border');
        await _runMap!.style.removeStyleSource('territory-area-source');
      } catch (e) {
        // Territory layers might not exist
      }
      
      print('Path, dotted line, and territory area cleared from map');
    } catch (e) {
      print('Error clearing path from map: $e');
    }
  }
}
