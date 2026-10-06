import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../controllers/map/map_controller.dart';
// import '../../services/mapbox_config.dart';
import '../../controllers/map/run_tracker_controller.dart';
import '../../controllers/map/territory_display_controller.dart';
import '../../core/enums/run_state.dart';
import '../../services/location_service.dart';
import '../../services/location_permission_service.dart';
// import '../../services/database_service.dart';
// import '../../models/territory/territory_model.dart';
// import '../../core/enums/run_state.dart';
import 'components/run_controls_widget.dart';
import 'components/run_stats_widget.dart';


class RunPageAutoStart extends StatefulWidget {
  final bool autoStart;
  const RunPageAutoStart({super.key, this.autoStart = false});

  @override
  State<RunPageAutoStart> createState() => _RunPageState();
}

class _RunPageState extends State<RunPageAutoStart> {
  late MapController mapController;
  late RunTrackerController runController;
  late TerritoryDisplayController territoryController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    mapController = Get.find<MapController>();
    
    // Initialize territory display controller for strategic planning
    if (!Get.isRegistered<TerritoryDisplayController>()) {
      territoryController = Get.put(TerritoryDisplayController());
    } else {
      territoryController = Get.find<TerritoryDisplayController>();
    }
    
    // Initialize or find run tracker controller
    if (!Get.isRegistered<RunTrackerController>()) {
      runController = Get.put(RunTrackerController());
    } else {
      runController = Get.find<RunTrackerController>();
    }
    
    // Ensure location service is active for run tracking
    _initializeLocationForRun();
  }
  
  void _initializeLocationForRun() async {
    final locationService = Get.find<LocationService>();
    
    // Ensure location permission service is initialized
    if (!Get.isRegistered<LocationPermissionService>()) {
      Get.put(LocationPermissionService());
    }
    
    // Request high accuracy location for run tracking
    await locationService.requestLocationPermission();
    
    // Start location tracking if not already active
    if (locationService.currentPosition.value == null) {
      print('Initializing location service for run tracking');
      // This will trigger location updates and populate currentPosition
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Intercept back: if a run is active or paused, show stop confirmation
        final controller = Get.find<RunTrackerController>();
        final isActive = controller.runState.value == RunState.running || controller.runState.value == RunState.paused;
        if (isActive) {
          final confirmed = await _showStopConfirmationBlocking(controller);
          if (confirmed) {
            controller.stopRun();
            // After stopping, allow popping this route
            if (context.mounted) Navigator.of(context).maybePop();
          }
        } else {
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark theme for run page
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text(
          'Territory Run',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Live tracking map
          _buildLiveTrackingMap(),
          
          // Run stats overlay (top-left - expanded to full width)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: const RunStatsWidget(),
          ),
          
          // Conquest test buttons removed
          
          // Run controls (bottom)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Builder(
              builder: (context) {
                return RunControlsWidget(autoStart: widget.autoStart);
              },
            ),
          ),
          

        ],
      ),
      ),
    );
  }

  Widget _buildLiveTrackingMap() {
    return MapWidget(
      key: const ValueKey('run_tracking_map'),
      cameraOptions: _getRunCameraOptions(),
      styleUri: mapController.initialMapStyle,
      textureView: true,
      onMapCreated: _onRunMapCreated,
    );
  }

  CameraOptions _getRunCameraOptions() {
    // Start centered on user with close zoom for detailed tracking
    final userPosition = Get.find<LocationService>().currentPosition.value;
    
    if (userPosition != null) {
      return CameraOptions(
        center: Point(coordinates: Position.named(
          lng: userPosition.longitude,
          lat: userPosition.latitude,
        )),
        zoom: 17.0,
        bearing: 0.0,
        pitch: 0.0,
      );
    }
    
    // Fallback to London
    return CameraOptions(
      center: Point(coordinates: Position.named(lng: -0.1276, lat: 51.5074)),
      zoom: 15.0,
      bearing: 0.0,
      pitch: 0.0,
    );
  }

  void _onRunMapCreated(MapboxMap map) async {
    print('Run tracking map created');
    runController.initializeRunMap(map);
    
    // Initialize territory display so user can see where to run strategically
    territoryController.initializeWithMap(map);
    
    // Enable location tracking with blue dot
    await _enableLocationTracking(map);
  }

  Future<void> _enableLocationTracking(MapboxMap map) async {
    try {
      // Enable location component (blue dot)
      await map.location.updateSettings(LocationComponentSettings(
        enabled: true,
        locationPuck: LocationPuck(
          locationPuck2D: DefaultLocationPuck2D(
            bearingImage: null, // Use default bearing indicator
            shadowImage: null,  // Use default shadow
            topImage: null,      // Use default blue dot
          ),
        ),
      ));
      
      print('Location tracking enabled on run map');
    } catch (e) {
      print('Error enabling location tracking: $e');
    }
  }

  Future<bool> _showStopConfirmationBlocking(RunTrackerController controller) async {
    final ctx = Get.context ?? context;
    final result = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Stop Run', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to stop this run?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }
}
