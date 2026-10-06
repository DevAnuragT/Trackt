import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../controllers/map/map_controller.dart';
import '../../controllers/map/territory_display_controller.dart';
import '../../controllers/map/run_path_display_controller.dart';
import '../../controllers/location/location_controller.dart';
import '../../services/location_service.dart';
import 'components/map_controls_widget.dart';
import 'components/bottom_sheet_widget.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapController mapController;
  late LocationController locationController;
  late TerritoryDisplayController territoryDisplayController;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with simplified approach for faster startup
    try {
      // Initialize core services only
      if (!Get.isRegistered<LocationService>()) {
        Get.put(LocationService());
      }
      
      // Initialize essential controllers directly - no checking for existing
      mapController = Get.put(MapController(), permanent: true);
      locationController = Get.put(LocationController(), permanent: true);
      territoryDisplayController = Get.put(TerritoryDisplayController(), permanent: true);
      
      // Initialize secondary controllers
      Get.put(RunPathDisplayController(), permanent: true);
      
    } catch (e) {
      print('Error initializing controllers: $e');
      // Create minimal controllers as fallback
      mapController = MapController();
      locationController = LocationController();
    }
    
    // Map style will be initialized automatically in the controller
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't refresh territories here - wait for map to be ready
    // This prevents the timing issue where territories are loaded before map is initialized
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Main map widget
            _buildMapWidget(),
            
            // Map controls (zoom, recenter)
            const Positioned(
              right: 16,
              top: 60,
              child: MapControlsWidget(),
            ),
            
            // Bottom sheet with territory info and run controls
            const TerritoryBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    // Simple map widget creation for faster loading
    return MapWidget(
      key: const ValueKey('mapbox_map'),
      cameraOptions: _getInitialCameraOptions(),
      styleUri: mapController.initialMapStyle,
      textureView: true,
      onMapCreated: mapController.onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onTapListener: territoryDisplayController.onMapTap,
    );
  }

  CameraOptions _getInitialCameraOptions() {
    // Start with a reasonable default, will be updated to user location
    return CameraOptions(
      center: Point(coordinates: Position.named(lng: -0.1276, lat: 51.5074)), // London fallback
      zoom: 13.0, // Good zoom level for 2km territory radius
      bearing: 0.0,
      pitch: 0.0,
    );
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    print('Map style loaded - initializing territories');
    
    // Initialize territory display after map is ready
    territoryDisplayController.initializeWithMap(mapController.mapboxMap!);
    // Center on user location after map is ready
    _centerOnUserLocation();
  }




  
  Future<void> _centerOnUserLocation() async {
    try {
      // Wait a bit for location services to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted && mapController.mapboxMap != null) {
        // Get the location service directly
        final locationService = Get.find<LocationService>();
        
        // Check if we have a current location
        final currentLocation = await locationService.getCurrentPosition();
        
        if (currentLocation != null) {
          print('🗺️ Centering map on user location: ${currentLocation.latitude}, ${currentLocation.longitude}');
          
          // Animate to user location
          await mapController.mapboxMap!.flyTo(
            CameraOptions(
              center: Point(coordinates: Position.named(
                lng: currentLocation.longitude,
                lat: currentLocation.latitude,
              )),
              zoom: 16.0, // Good zoom for territory viewing
              bearing: 0.0,
              pitch: 0.0,
            ),
            MapAnimationOptions(duration: 2000), // 2 second smooth animation
          );
          
          print('✅ Map centered on user location');
        } else {
          print('⚠️ No current location available, trying to get high accuracy location...');
          
          // Try to get a high accuracy location
          final highAccuracyLocation = await locationService.getHighAccuracyLocation();
          
          if (highAccuracyLocation != null) {
            print('🗺️ Centering map on high accuracy location: ${highAccuracyLocation.latitude}, ${highAccuracyLocation.longitude}');
            
            await mapController.mapboxMap!.flyTo(
              CameraOptions(
                center: Point(coordinates: Position.named(
                  lng: highAccuracyLocation.longitude,
                  lat: highAccuracyLocation.latitude,
                )),
                zoom: 16.0,
                bearing: 0.0,
                pitch: 0.0,
              ),
              MapAnimationOptions(duration: 2000),
            );
            
            print('✅ Map centered on high accuracy location');
          } else {
            print('⚠️ Could not get any location, staying at default position');
          }
        }
      }
    } catch (e) {
      print('❌ Error centering on user location: $e');
    }
  }
}
