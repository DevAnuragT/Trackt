import 'dart:async';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../services/location_service.dart';
import '../../services/mapbox_config.dart';
import '../../models/territory/territory_model.dart';
import 'territory_display_controller.dart';
import 'run_path_display_controller.dart';
import '../../services/location_permission_service.dart';

class MapController extends GetxController {
  final LocationService _locationService = Get.find<LocationService>();
  
  // Map controller
  MapboxMap? mapboxMap;
  
  // Control whether to auto-center on user when map becomes ready
  bool autoCenterOnLocation = true;
  
  // Observable map state
  final RxBool isMapReady = false.obs;
  final Rx<CameraOptions?> currentCameraPosition = Rx<CameraOptions?>(null);
  final RxList<Territory> visibleTerritories = <Territory>[].obs;
  
  // Map style - from env with fallback
  final RxString currentMapStyle = MapboxConfig.styleUri.obs;
  
  // Default style fallback
  static const String defaultStyle = "mapbox://styles/mapbox/outdoors-v12";
  
  /// Get current map style from env
  String get initialMapStyle {
    return currentMapStyle.value.isNotEmpty ? currentMapStyle.value : defaultStyle;
  }
  
    @override
  void onInit() {
    super.onInit();
    _initializeMapStyle();
    
    // Update map style based on time of day every hour
    Timer.periodic(const Duration(hours: 1), (timer) {
      // Map is initialized - style already set
    });
  }

  @override
  void onClose() {
    // Clean up timer when controller is disposed
    _cameraChangeTimer?.cancel();
    mapboxMap = null;
    super.onClose();
  }
  
  /// Initialize map style from env
  void _initializeMapStyle() {
    currentMapStyle.value = MapboxConfig.styleUri;
    print('Map style set from env: ${currentMapStyle.value}');
  }
  
  /// Apply style change to existing map
  Future<void> _applyStyleChange(String styleUri) async {
    if (mapboxMap == null) return;
    
    try {
      await mapboxMap!.style.setStyleURI(styleUri);
      print('Map style changed to: $styleUri');
      
      // Re-add user location layer after style change
      await Future.delayed(const Duration(milliseconds: 500));
      await _addUserLocationLayer();
      // Add 3D buildings for depth
      await add3DBuildingsLayer();
    } catch (e) {
      print('Error applying style change: $e');
    }
  }

  void onMapCreated(MapboxMap map) {
    print('onMapCreated callback triggered');
    mapboxMap = map;
    
    // Set map ready immediately to stop loading indicator
    isMapReady.value = true;
    
    // Apply configured style immediately
    _applyStyleChange(initialMapStyle);
    
    // Set up map features
    _setupMapListeners();
    _addUserLocationLayer();
    
    // Initialize territory display controller with this map
    if (Get.isRegistered<TerritoryDisplayController>()) {
      final territoryController = Get.find<TerritoryDisplayController>();
      territoryController.initializeWithMap(map);
      print('Territory display controller initialized with main map');
    }
    
    // Initialize run path display controller with this map
    if (Get.isRegistered<RunPathDisplayController>()) {
      final runPathController = Get.find<RunPathDisplayController>();
      runPathController.initializeWithMap(map);
      print('Run path display controller initialized with main map');
    }
    
    // Start watching for user location and animate to it when available
    if (autoCenterOnLocation) {
      _startLocationWatcher();
    }
    
    print('Map ready and initialized');
  }
  
  /// Add 3D buildings layer when style is loaded (simplified version)
  Future<void> add3DBuildingsLayer() async {
    if (mapboxMap == null) return;
    
    try {
      print('Adding 3D buildings layer...');
      
      // Building colors for day mode
      final buildingColor = 0xFFE0E0E0; // Light gray for day
      final buildingOpacity = 0.6;
      
      // Create a simple 3D buildings layer with fixed height
      await mapboxMap!.style.addLayer(
        FillExtrusionLayer(
          id: "3d-buildings",
          sourceId: "composite",
          sourceLayer: "building", 
          minZoom: 15,
          fillExtrusionColor: buildingColor,
          fillExtrusionOpacity: buildingOpacity,
          fillExtrusionHeight: 20.0, // Fixed height for all buildings
        ),
      );
      
      print('3D buildings layer added successfully');
    } catch (e) {
      print('Error adding 3D buildings layer: $e');
      // Try an even simpler approach
      await _addBasic3DBuildings();
    }
  }
  
  /// Fallback 3D buildings with basic settings
  Future<void> _addBasic3DBuildings() async {
    try {
      await mapboxMap!.style.addLayer(
        FillExtrusionLayer(
          id: "basic-3d-buildings",
          sourceId: "composite",
          sourceLayer: "building",
          minZoom: 15,
          fillExtrusionColor: 0xFFCCCCCC,
          fillExtrusionOpacity: 0.6,
          fillExtrusionHeight: 15.0, // Fixed height for all buildings
        ),
      );
      print('Basic 3D buildings layer added');
    } catch (e) {
      print('Failed to add 3D buildings: $e');
    }
  }
  
  /// Watch for user location and automatically move to it when GPS is ready
  void _startLocationWatcher() {
    try {
      // Check if we already have location permission and position
      if (_locationService.hasLocationPermission.value) {
        final position = _locationService.currentPosition.value;
        if (position != null) {
          // We already have location, animate to it
          _animateToUserLocationSmoothly(position);
          return;
        }
      }
      
      // Listen for location updates and animate to first valid location
      _locationService.getLocationStream().take(1).listen((position) {
        print('Got user location: ${position.latitude}, ${position.longitude}');
        _animateToUserLocationSmoothly(position);
      }).onError((error) {
        print('Location stream error: $error');
      });
    } catch (e) {
      print('Error starting location watcher: $e');
    }
  }
  
  /// Smooth animation to user location (called automatically when GPS is ready)
  Future<void> _animateToUserLocationSmoothly(geo.Position position) async {
    if (mapboxMap == null) return;
    
    print('Animating to user location...');
    await _animateToLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      zoom: 13.5, // Overview zoom
      pitch: 0.0, // Top-down view globally
      bearing: 0.0, // North-up
      duration: const Duration(milliseconds: 2000), // Smooth 2-second animation
    );
  }

  void _setupMapListeners() {
    if (mapboxMap == null) return;
    
    // Set up camera change listener to fetch territories when user pans/zooms
    _setupCameraChangeListener();
    print('Map listeners set up');
  }

  /// Set up camera change listener to fetch territories for new areas
  void _setupCameraChangeListener() {
    if (mapboxMap == null) return;
    
    // Use a more efficient approach with proper debouncing
    // Check for camera changes every 1 second, but only fetch territories if moved significantly
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mapboxMap == null) {
        timer.cancel();
        return;
      }
      
      _checkForCameraChange();
    });
  }

  /// Check if camera has moved significantly and fetch territories if needed
  Future<void> _checkForCameraChange() async {
    if (mapboxMap == null) return;
    
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      final currentCenter = currentCamera.center;
      
      // Check if camera has moved significantly (more than 1km for better performance)
      if (_lastCameraCenter != null) {
        final distance = _calculateDistance(
          _lastCameraCenter!.coordinates.lat.toDouble(),
          _lastCameraCenter!.coordinates.lng.toDouble(),
          currentCenter.coordinates.lat.toDouble(),
          currentCenter.coordinates.lng.toDouble(),
        );
        
        // If moved more than 1km, fetch territories for new area
        if (distance > 1000) {
          print('🗺️ Camera moved ${distance.toStringAsFixed(0)}m, fetching territories for new area');
          
          // Debounce: cancel any pending fetch and start a new one
          _cameraChangeTimer?.cancel();
          _cameraChangeTimer = Timer(const Duration(milliseconds: 500), () async {
            await _fetchTerritoriesForCameraPosition(
              currentCenter.coordinates.lat.toDouble(),
              currentCenter.coordinates.lng.toDouble(),
            );
          });
          
          _lastCameraCenter = currentCenter;
        }
      } else {
        // First time, just store the position
        _lastCameraCenter = currentCenter;
      }
    } catch (e) {
      print('❌ Error checking camera change: $e');
    }
  }

  // Store last camera center for comparison
  Point? _lastCameraCenter;
  
  // Timer for debouncing camera changes
  Timer? _cameraChangeTimer;

  /// Fetch territories for a specific camera position
  Future<void> _fetchTerritoriesForCameraPosition(double lat, double lng) async {
    try {
      // Get territory display controller and refresh territories for new location
      if (Get.isRegistered<TerritoryDisplayController>()) {
        final territoryController = Get.find<TerritoryDisplayController>();
        await territoryController.refreshTerritoriesForNewLocation(lat, lng);
      }
    } catch (e) {
      print('❌ Error fetching territories for camera position: $e');
    }
  }

  /// Manually refresh territories for current camera position (for testing/debugging)
  Future<void> refreshTerritoriesForCurrentView() async {
    if (mapboxMap == null) return;
    
    try {
      final currentCamera = await mapboxMap!.getCameraState();
      final currentCenter = currentCamera.center;
      
      print('🔄 Manually refreshing territories for current view: ${currentCenter.coordinates.lat}, ${currentCenter.coordinates.lng}');
      
      await _fetchTerritoriesForCameraPosition(
        currentCenter.coordinates.lat.toDouble(),
        currentCenter.coordinates.lng.toDouble(),
      );
      
      // Update the last camera center to prevent immediate re-fetch
      _lastCameraCenter = currentCenter;
    } catch (e) {
      print('❌ Error manually refreshing territories: $e');
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Future<void> _addUserLocationLayer() async {
    if (mapboxMap == null) return;
    
    try {
      // Enable location component with high accuracy settings
      await mapboxMap!.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          showAccuracyRing: false, // Remove blue accuracy circle
          pulsingEnabled: false, // Disable pulsing
          puckBearing: PuckBearing.HEADING, // Show device orientation
          puckBearingEnabled: true,
        ),
      );
      print('High-accuracy user location layer added');
    } catch (e) {
      print('Error adding user location layer: $e');
    }
  }

  /// Switch map style for better territory visualization
  Future<void> switchMapStyle(String newStyle) async {
    if (mapboxMap == null) return;
    
    try {
      await mapboxMap!.style.setStyleURI(newStyle);
      currentMapStyle.value = newStyle;
      
      // Re-add user location layer after style change
      await _addUserLocationLayer();
    } catch (e) {
      print('Error switching map style: $e');
    }
  }

  Future<void> _animateToLocation({
    required double latitude,
    required double longitude,
    double zoom = 15.0,
    double pitch = 0.0,
    double bearing = 0.0,
    Duration duration = const Duration(milliseconds: 1000),
  }) async {
    if (mapboxMap == null) return;
    
    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position.named(lng: longitude, lat: latitude)),
      zoom: zoom,
      bearing: bearing,
      pitch: pitch,
    );
    
    currentCameraPosition.value = cameraOptions;
    
    // Animate to the new position
    await mapboxMap!.flyTo(
      cameraOptions,
      MapAnimationOptions(duration: duration.inMilliseconds),
    );
  }

  /// Public helper to animate the camera to coordinates
  Future<void> animateTo({
    required double latitude,
    required double longitude,
    double zoom = 16.0,
    double pitch = 0.0,
    double bearing = 0.0,
    Duration duration = const Duration(milliseconds: 800),
  }) async {
    await _animateToLocation(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
      pitch: pitch,
      bearing: bearing,
      duration: duration,
    );
  }

  // Public methods for map control
  Future<void> moveToUserLocation() async {
    try {
      // Check if we have location permission first
      if (!_locationService.hasLocationPermission.value) {
        print('🔍 No location permission, requesting...');
        
        // Use LocationPermissionService to handle permission requests properly
        final permissionService = Get.find<LocationPermissionService>();
        
        // Use smart permission check to avoid duplicate dialogs
        bool hasPermission = await permissionService.smartCheckLocationPermissions();
        if (!hasPermission) {
          print('❌ Location permission denied');
          return;
        }
        
        // Update location service state
        await _locationService.requestLocationPermission();
      }
      
      // Get fresh, high-accuracy location
      geo.Position geoPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
      
      print('High-accuracy position: ${geoPosition.latitude}, ${geoPosition.longitude} (±${geoPosition.accuracy}m)');
      
      await _animateToLocation(
        latitude: geoPosition.latitude,
        longitude: geoPosition.longitude,
        zoom: 18.0, // Closer zoom for precise viewing
        pitch: 0.0, // Top-down
        bearing: 0.0, // North-up
      );
      
      Get.snackbar(
        'High-Accuracy Location',
        'Centered on GPS location (±${geoPosition.accuracy.toStringAsFixed(1)}m)',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Error in moveToUserLocation: $e');
      
      String errorMessage = 'Failed to get your location: ';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage += 'Location permission was denied';
      } else if (e.toString().contains('LOCATION_SERVICE_DISABLED')) {
        errorMessage += 'Location services are disabled';
      } else if (e.toString().contains('TIMEOUT') || e.toString().contains('TimeoutException')) {
        errorMessage += 'GPS timeout. Try moving to an open area';
      } else {
        errorMessage += 'GPS error. Check location settings';
      }
      
      Get.snackbar(
        'Location Error',
        errorMessage,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> zoomIn() async {
    if (mapboxMap == null) return;
    
    final currentCamera = await mapboxMap!.getCameraState();
    final newZoom = (currentCamera.zoom + 1.0).clamp(0.0, 22.0);
    
    await mapboxMap!.flyTo(
      CameraOptions(zoom: newZoom),
      MapAnimationOptions(duration: 300),
    );
  }

  Future<void> zoomOut() async {
    if (mapboxMap == null) return;
    
    final currentCamera = await mapboxMap!.getCameraState();
    final newZoom = (currentCamera.zoom - 1.0).clamp(0.0, 22.0);
    
    await mapboxMap!.flyTo(
      CameraOptions(zoom: newZoom),
      MapAnimationOptions(duration: 300),
    );
  }

  // Method to add polyline for active run
  Future<void> addRunPolyline(List<LatLngPoint> points, {String color = '#FF0000'}) async {
    if (mapboxMap == null || points.length < 2) return;
    
    // Convert LatLngPoint to Position for Mapbox
    List<Position> positions = points.map((point) => 
      Position.named(lng: point.longitude, lat: point.latitude)
    ).toList();
    
    // TODO: Add polyline to map using proper Mapbox v2 API
    // This will use the positions list above
    print('Adding run polyline with ${points.length} points (${positions.length} positions)');
  }

  // Method to add territory polygons
  Future<void> addTerritoryPolygon(Territory territory) async {
    if (mapboxMap == null) return;
    
    // Convert boundary points to positions
    List<Position> positions = territory.boundaryPoints.map((point) => 
      Position.named(lng: point.longitude, lat: point.latitude)
    ).toList();
    
    // Close the polygon if not already closed
    if (positions.isNotEmpty && positions.first != positions.last) {
      positions.add(positions.first);
    }
    
    // TODO: Add filled polygon to map using proper Mapbox v2 API
    print('Adding territory polygon for ${territory.ownerId}');
  }

  Future<void> clearMap() async {
    if (mapboxMap == null) return;
    
    // TODO: Clear all polylines and polygons
    print('Clearing map');
  }
}
