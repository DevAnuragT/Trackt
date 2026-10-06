import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../../models/territory/territory_model.dart';
import '../../services/territory_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/database_service.dart';

class TerritoryDisplayController extends GetxController {
  final TerritoryService _territoryService = Get.find<TerritoryService>();

  // Observable state
  final RxBool isLoadingTerritories = false.obs;
  final RxList<Territory> displayedTerritories = <Territory>[].obs;
  final RxList<String> addedTerritoryIds = <String>[].obs;

  // Map reference
  MapboxMap? _mapboxMap;

  // Configuration
  static const int radiusMeters = 2000;
  static const double maxTerritoryDisplayDistance = 3000;

  @override
  void onInit() {
    super.onInit();
    
    // Watch for territory changes
    ever(_territoryService.userTerritories, (territories) {
      if (_mapboxMap != null) {
        refreshTerritories();
      }
    });
  }

  /// Initialize with map reference
  void initializeWithMap(MapboxMap mapboxMap) {
    print('🗺️ TerritoryDisplayController: Initializing with map reference');
    _mapboxMap = mapboxMap;
    print('🗺️ TerritoryDisplayController: Map reference set, waiting for map to be fully ready...');
    
    // Wait a bit for the map to be fully ready before adding territories
    Future.delayed(const Duration(milliseconds: 500), () {
      print('🗺️ TerritoryDisplayController: Map should be ready now, refreshing territories');
      refreshTerritories();
    });
  }



  /// Handle map taps to show territory information
  void onMapTap(MapContentGestureContext context) async {
    try {
      // Get the screen coordinate from the tap context
      final screenCoord = context.touchPosition;
      print('🗺️ Map tapped at screen coordinates: (${screenCoord.x}, ${screenCoord.y})');
      
      // Check if we have any territories to query
      if (addedTerritoryIds.isEmpty) {
        print('⚠️ No territories available for querying');
        return;
      }
      
      // Query rendered features at the tap point
      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(
          layerIds: addedTerritoryIds.map((id) => 'territory-fill-$id').toList(),
        ),
      );

      print('🔍 Query returned ${features.length} features');
      
      if (features.isNotEmpty) {
        // Get the first territory feature
        final queriedFeature = features.first;
        if (queriedFeature != null) {
          final feature = queriedFeature.queriedFeature.feature;
          final properties = feature['properties'];
          
          print('🔍 Feature properties type: ${properties.runtimeType}');
          print('🔍 Feature properties: $properties');
          
          if (properties != null && properties is Map) {
            // Safely extract properties with proper type checking
            final territoryId = _safeExtractString(properties, 'id');
            final ownerId = _safeExtractString(properties, 'owner_id');
            final area = _safeExtractNumber(properties, 'area');
            
            print('🔍 Extracted - ID: $territoryId, Owner: $ownerId, Area: $area');
            
            if (territoryId != null && ownerId != null && area != null) {
              // Find the territory object for additional details
              final territory = _territoryService.nearbyTerritories
                  .firstWhereOrNull((t) => t.id == territoryId);
              
              if (territory != null) {
                print('✅ Found territory, showing info: ${territory.id}');
                _showTerritoryInfo(territory, ownerId, area.toDouble());
              } else {
                print('⚠️ Territory not found in service: $territoryId');
              }
            } else {
              print('⚠️ Missing required properties - ID: $territoryId, Owner: $ownerId, Area: $area');
            }
          } else {
            print('⚠️ Properties is null or not a Map: $properties');
          }
        } else {
          print('⚠️ Queried feature is null');
        }
      } else {
        print('ℹ️ No features found at tap location');
      }
    } catch (e) {
      print('❌ Error handling map tap: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Show territory information in a bottom sheet
  void _showTerritoryInfo(Territory territory, String ownerId, double area) async {
    try {
      // Get owner display name
      final databaseService = Get.find<DatabaseService>();
      String ownerName = 'Unknown User';
      
      try {
        final profile = await databaseService.getUserProfile(ownerId);
        if (profile != null) {
          ownerName = profile['display_name'] ?? 'Unknown User';
        }
      } catch (e) {
        print('⚠️ Could not fetch owner profile: $e');
      }

      // Format area
      String areaText = '${(area / 1000000).toStringAsFixed(2)} km²';

      // Show bottom sheet
      Get.bottomSheet(
        _TerritoryInfoBottomSheet(
          territory: territory,
          ownerName: ownerName,
          area: areaText,
          ownerId: ownerId,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      );
    } catch (e) {
      print('❌ Error showing territory info: $e');
    }
  }

  /// Refresh territories display (called after conquests or map initialization)
  Future<void> refreshTerritories() async {
    try {
      print('🔄 Refreshing territories display...');
      
      // Check if map is ready
      if (_mapboxMap == null) {
        print('⚠️ Map not ready yet, skipping territory refresh');
        return;
      }
      
      // Check if map style is loaded
      try {
        await _mapboxMap!.style.isStyleLoaded();
        print('✅ Map style is loaded and ready');
      } catch (e) {
        print('⚠️ Map style not fully loaded yet, waiting...');
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          await _mapboxMap!.style.isStyleLoaded();
          print('✅ Map style is now loaded');
        } catch (e2) {
          print('❌ Map style still not loaded after waiting: $e2');
          return;
        }
      }
      
      // Refresh from territory service with proper layering for map display
      await _territoryService.refreshNearbyTerritoriesForMapDisplay();
      
      // Update map display
      await _updateTerritoriesOnMap();
      
      print('✅ Territories display refreshed');
    } catch (e) {
      print('❌ Error refreshing territories display: $e');
    }
  }

  /// Refresh territories for a new location when camera moves significantly
  Future<void> refreshTerritoriesForNewLocation(double latitude, double longitude) async {
    try {
      print('🔄 Refreshing territories for new location: $latitude, $longitude');
      
      // Check if map is ready
      if (_mapboxMap == null) {
        print('⚠️ Map not ready yet, skipping territory refresh for new location');
        return;
      }
      
      // Check if map style is loaded
      try {
        await _mapboxMap!.style.isStyleLoaded();
        print('✅ Map style is loaded and ready for new location');
      } catch (e) {
        print('⚠️ Map style not fully loaded yet, waiting...');
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          await _mapboxMap!.style.isStyleLoaded();
          print('✅ Map style is now loaded for new location');
        } catch (e2) {
          print('❌ Map style still not loaded after waiting: $e2');
          return;
        }
      }
      
      // Refresh territories for the new location using the territory service
      await _territoryService.refreshNearbyTerritoriesForLocation(latitude, longitude);
      
      // Update map display
      await _updateTerritoriesOnMap();
      
      print('✅ Territories refreshed for new location: $latitude, $longitude');
    } catch (e) {
      print('❌ Error refreshing territories for new location: $e');
    }
  }

  /// Update territories display on map
  Future<void> _updateTerritoriesOnMap() async {
    if (_mapboxMap == null) return;

    try {
      // Clear existing territory layers
      await _clearExistingTerritories();

      // Get territories from service
      List<Territory> territories = _territoryService.nearbyTerritories;
      print('🔍 Territory service returned ${territories.length} territories');

      // Use the proper layering logic from the database function
      // The territories are already sorted by render_order from get_territories_for_map_display
      // No need to re-sort here as it would override the database layering logic

      // Add territories to map in chronological order (oldest first = bottom layer)
      print('🔍 Processing ${territories.length} territories for map display');
      if (territories.isEmpty) {
        print('⚠️ No territories to display - this might be the issue!');
        print('🔍 Checking if territory service has data...');
        // Try to force a refresh to see if data is available
        await _territoryService.refreshNearbyTerritoriesForMapDisplay();
        territories = _territoryService.nearbyTerritories;
        print('🔍 After forced refresh: ${territories.length} territories');
        
        // If still empty, wait a bit more and try again
        if (territories.isEmpty) {
          print('⚠️ Still no territories after refresh, waiting and trying again...');
          await Future.delayed(const Duration(milliseconds: 2000));
          await _territoryService.refreshNearbyTerritoriesForMapDisplay();
          territories = _territoryService.nearbyTerritories;
          print('🔍 After second attempt: ${territories.length} territories');
        }
      }
      
      for (Territory territory in territories) {
        print('🔍 Processing territory: ${territory.id} (owner: ${territory.ownerId}, area: ${territory.area})');
        await _addTerritoryToMap(territory);
      }

      print('✅ Updated ${territories.length} territories on map');
      
  // Do not refresh bottom sheet stats on camera/map refresh; stats don't change with location
    } catch (e) {
      print('❌ Error updating territories on map: $e');
    }
  }
  
  /// Clear existing territories from map
  Future<void> _clearExistingTerritories() async {
    if (_mapboxMap == null) return;

    try {
      // Remove all previously added territories
      for (String territoryId in addedTerritoryIds) {
        await _removeTerritoryFromMap(territoryId);
      }
      addedTerritoryIds.clear();
    } catch (e) {
      // Error handling silently
    }
  }
  
  /// Remove specific territory from map (commented out for now)
  Future<void> _removeTerritoryFromMap(String territoryId) async {
    if (_mapboxMap == null) return;
    
    String sourceId = 'territory-source-$territoryId';
    String fillLayerId = 'territory-fill-$territoryId';
    String borderLayerId = 'territory-border-$territoryId';

    try {
      await _mapboxMap!.style.removeStyleLayer(fillLayerId);
      await _mapboxMap!.style.removeStyleLayer(borderLayerId);
      await _mapboxMap!.style.removeStyleSource(sourceId);
      addedTerritoryIds.remove(territoryId);
    } catch (e) {
      // Layer/source might not exist, continue silently
    }
  }

  /// Add single territory to map
  Future<void> _addTerritoryToMap(Territory territory) async {
    if (_mapboxMap == null) return;

    String sourceId = 'territory-source-${territory.id}';
    String fillLayerId = 'territory-fill-${territory.id}';
    String borderLayerId = 'territory-border-${territory.id}';

    print('🔍 _addTerritoryToMap: Territory ${territory.id} - boundaryRings: ${territory.boundaryRings?.length ?? 0}, boundaryPoints: ${territory.boundaryPoints.length}');

    try {
      // Build full GeoJSON including holes and multipolygons
      String geoJsonData;
      if (territory.boundaryRings != null && territory.boundaryRings!.isNotEmpty) {
        // Convert RingPart list to MultiPolygon coordinates [[[lng,lat]...],[hole...]...]
        final multiPoly = territory.boundaryRings!.map((part) {
          final outer = part.outer
              .map((p) => [p.longitude, p.latitude])
              .toList();
          if (outer.isNotEmpty && (outer.first[0] != outer.last[0] || outer.first[1] != outer.last[1])) {
            outer.add(List<double>.from(outer.first));
          }
          final holes = part.holes.map((ring) {
            final coords = ring.map((p) => [p.longitude, p.latitude]).toList();
            if (coords.isNotEmpty && (coords.first[0] != coords.last[0] || coords.first[1] != coords.last[1])) {
              coords.add(List<double>.from(coords.first));
            }
            return coords;
          }).toList();
          // One polygon: [ outer, ...holes ]
          return [outer, ...holes];
        }).toList();

        // If only one part, emit Polygon; else MultiPolygon
        if (multiPoly.length == 1) {
          final rings = multiPoly.first;
          final ringsString = rings.map((ring) => '[${ring.map((c) => '[${c[0]}, ${c[1]}]').join(',')}]').join(',');
          geoJsonData = '''
          {
            "type": "Feature",
            "properties": {
              "id": "${territory.id}",
              "owner_id": "${territory.ownerId}",
              "area": ${territory.area}
            },
            "geometry": {
              "type": "Polygon",
              "coordinates": [$ringsString]
            }
          }
          ''';
          print('🔍 Generated Polygon GeoJSON for territory ${territory.id}: $geoJsonData');
        } else {
          final polysString = multiPoly.map((poly) {
            final ringsString = poly.map((ring) => '[${ring.map((c) => '[${c[0]}, ${c[1]}]').join(',')}]').join(',');
            return '[$ringsString]';
          }).join(',');
          geoJsonData = '''
          {
            "type": "Feature",
            "properties": {
              "id": "${territory.id}",
              "owner_id": "${territory.ownerId}",
              "area": ${territory.area}
            },
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [$polysString]
            }
          }
          ''';
          print('🔍 Generated MultiPolygon GeoJSON for territory ${territory.id}: $geoJsonData');
        }
      } else {
        // Fallback to flat boundaryPoints (no holes)
        List<List<double>> coordinates = territory.boundaryPoints.map((point) => [point.longitude, point.latitude]).toList();
        if (coordinates.isNotEmpty && (coordinates.first[0] != coordinates.last[0] || coordinates.first[1] != coordinates.last[1])) {
          coordinates.add(List<double>.from(coordinates.first));
        }
        String coordinatesString = coordinates.map((coord) => '[${coord[0]}, ${coord[1]}]').join(',');
        geoJsonData = '''
        {
          "type": "Feature",
          "properties": {
            "id": "${territory.id}",
            "owner_id": "${territory.ownerId}",
            "area": ${territory.area}
          },
          "geometry": {
            "type": "Polygon",
            "coordinates": [[$coordinatesString]]
          }
        }
        ''';
        print('🔍 Generated flat Polygon GeoJSON for territory ${territory.id}: $geoJsonData');
      }

      // Add source
      print('🔍 Adding source for territory ${territory.id} with GeoJSON: $geoJsonData');
      try {
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: sourceId,
          data: geoJsonData,
        ));
        print('✅ Successfully added source for territory ${territory.id}');
      } catch (e) {
        if (e.toString().contains('already exists')) {
          print('⚠️ Source already exists for territory ${territory.id}');
          return; // Skip if already exists
        } else {
          print('❌ Error adding source for territory ${territory.id}: $e');
          rethrow;
        }
      }

      // Determine colors based on ownership
      String? currentUserId = _territoryService.currentUserId;
      bool isOwnTerritory = territory.ownerId == currentUserId || 
                           (currentUserId == null && territory.ownerId == 'current_user');
      bool isTestTerritory = territory.id.contains('test_territory') || territory.ownerId == 'test_user';
      
      // Get color from territory owner (this is the key fix!)
      Color fillColor;
      Color borderColor;
      
      if (isOwnTerritory) {
        // Use current user's color for own territories
        try {
          final userPrefs = Get.find<UserPreferencesService>();
          fillColor = userPrefs.userColor.value.withOpacity(0.9); // Unified opacity
          borderColor = userPrefs.userColor.value.withOpacity(0.9); // Border matches fill opacity
        } catch (e) {
          fillColor = Colors.blue.withOpacity(0.9); // Unified opacity
          borderColor = Colors.blue.withOpacity(0.9); // Border matches fill opacity
        }
      } else if (isTestTerritory) {
        // Test territories get purple
        fillColor = Colors.purple.withOpacity(0.9); // Unified opacity
        borderColor = Colors.purple.withOpacity(0.9); // Border matches fill opacity
      } else {
        // Other users' territories use THEIR color, not grey!
        if (territory.ownerColor != null && territory.ownerColor!.isNotEmpty) {
          try {
            // Parse hex color string to Color object
            String hexColor = territory.ownerColor!;
            if (hexColor.startsWith('#')) {
              hexColor = hexColor.substring(1);
            }
            // Ensure it's 8 characters (ARGB format)
            if (hexColor.length == 6) {
              hexColor = 'FF$hexColor'; // Add full opacity
            }
            int colorValue = int.parse(hexColor, radix: 16);
            fillColor = Color(colorValue).withOpacity(0.9); // Unified opacity
            borderColor = Color(colorValue).withOpacity(0.9); // Border matches fill opacity
          } catch (e) {
            print('❌ Error parsing owner color: ${territory.ownerColor} - $e');
            // Fallback to distinct colors for different users
            fillColor = _getDistinctColor(territory.ownerId).withOpacity(0.9); // Unified opacity
            borderColor = _getDistinctColor(territory.ownerId).withOpacity(0.9); // Border matches fill opacity
          }
        } else {
          // Fallback to distinct colors if no owner color available
          fillColor = _getDistinctColor(territory.ownerId).withOpacity(0.9); // Unified opacity
          borderColor = _getDistinctColor(territory.ownerId).withOpacity(0.9); // Border matches fill opacity
        }
      }

      // Configure visual styles with consistent opacity (0.9) for all territories
      double fillOpacity = 0.9; // Unified opacity for all territories
      double borderOpacity = 0.9; // Border opacity matches fill opacity
      double borderWidth = 2.0; // Consistent border width for all territories

      // Add fill layer
      print('🔍 Adding fill layer for territory ${territory.id} with color: $fillColor');
      try {
        int fillColorHex = _parseColorToHex(fillColor);
        await _mapboxMap!.style.addLayerAt(FillLayer(
          id: fillLayerId,
          sourceId: sourceId,
          fillColor: fillColorHex,
          fillOpacity: fillOpacity,
        ), LayerPosition(above: null, below: null, at: null));
        print('✅ Successfully added fill layer for territory ${territory.id}');
      } catch (e) {
        if (e.toString().contains('already exists')) {
          print('⚠️ Fill layer already exists for territory ${territory.id}');
          return;
        } else {
          print('❌ Error adding fill layer for territory ${territory.id}: $e');
          rethrow;
        }
      }

      // Add border layer
      print('🔍 Adding border layer for territory ${territory.id} with color: $borderColor');
      try {
        int borderColorHex = _parseColorToHex(borderColor);
        await _mapboxMap!.style.addLayerAt(LineLayer(
          id: borderLayerId,
          sourceId: sourceId,
          lineColor: borderColorHex,
          lineWidth: borderWidth,
          lineOpacity: borderOpacity,
        ), LayerPosition(above: fillLayerId, below: null, at: null));
        print('✅ Successfully added border layer for territory ${territory.id}');
        print('✅ Territory ${territory.id} fully added to map');
      } catch (e) {
        if (e.toString().contains('already exists')) {
          print('⚠️ Border layer already exists for territory ${territory.id}');
          return;
        } else {
          print('❌ Error adding border layer for territory ${territory.id}: $e');
          rethrow;
        }
      }

      addedTerritoryIds.add(territory.id);
      print('✅ Territory ${territory.id} successfully added to map');
    } catch (e) {
      print('❌ Error adding territory ${territory.id} to map: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Parse color to hex format for Mapbox
  int _parseColorToHex(Color color) {
    return color.value;
  }
  
  /// Generate distinct colors for different users (fallback when owner color not available)
  Color _getDistinctColor(String userId) {
    // Use a hash of the user ID to generate consistent colors
    int hash = userId.hashCode;
    
    // Generate distinct colors using the hash
    List<Color> distinctColors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.lime,
      Colors.deepPurple,
      Colors.brown,
    ];
    
    int colorIndex = hash.abs() % distinctColors.length;
    return distinctColors[colorIndex];
  }

  /// Get territories by ownership
  List<Territory> get ownTerritories {
    String currentUserId = 'current_user';
    return displayedTerritories.where((t) => t.ownerId == currentUserId).toList();
  }

  List<Territory> get otherUsersTerritories {
    String currentUserId = 'current_user';
    return displayedTerritories.where((t) => t.ownerId != currentUserId).toList();
  }

  /// Get summary statistics
  Map<String, dynamic> get territoryStats {
    List<Territory> own = ownTerritories;
    List<Territory> others = otherUsersTerritories;
    
    double ownTotalArea = own.fold(0, (sum, t) => sum + t.area);
    double othersTotalArea = others.fold(0, (sum, t) => sum + t.area);
    
    return {
      'own_count': own.length,
      'others_count': others.length,
      'own_total_area': ownTotalArea,
      'others_total_area': othersTotalArea,
      'total_displayed': displayedTerritories.length,
    };
  }
  
  /// Fly to a specific territory on the map
  Future<void> flyToTerritory(Territory territory) async {
    if (_mapboxMap == null) {
      print('❌ Map not initialized, cannot fly to territory');
      return;
    }
    
    try {
      print('🗺️ Flying to territory: ${territory.id}');
      
      // Calculate the center of the territory
      double centerLat = territory.center.latitude;
      double centerLng = territory.center.longitude;
      
      // Calculate appropriate zoom level based on territory area
      double zoomLevel = _calculateZoomForTerritory(territory.area);
      
      // Fly to the territory center
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position.named(
            lng: centerLng,
            lat: centerLat,
          )),
          zoom: zoomLevel,
          bearing: 0.0,
          pitch: 45.0, // Slight 3D tilt for better visibility
        ),
        MapAnimationOptions(duration: 2000), // 2 second animation
      );
      
      print('✅ Successfully flew to territory: ${territory.id}');
      
      // Show a brief snackbar to confirm the action
      Get.snackbar(
        'Territory Focused',
        '${(territory.area / 1000).toStringAsFixed(2)} km² territory',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      
    } catch (e) {
      print('❌ Error flying to territory: $e');
      Get.snackbar(
        'Navigation Error',
        'Could not focus on territory',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  /// Calculate appropriate zoom level based on territory area
  double _calculateZoomForTerritory(double areaInSquareMeters) {
    if (areaInSquareMeters < 1000) { // Less than 1 km²
      return 18.0; // Very close zoom
    } else if (areaInSquareMeters < 10000) { // Less than 10 km²
      return 17.0; // Close zoom
    } else if (areaInSquareMeters < 100000) { // Less than 100 km²
      return 16.0; // Medium zoom
    } else if (areaInSquareMeters < 1000000) { // Less than 1000 km²
      return 15.0; // Medium-far zoom
    } else {
      return 14.0; // Far zoom for very large territories
    }
  }

  /// Safely extract a string value from a Map
  String? _safeExtractString(Map properties, String key) {
    try {
      final value = properties[key];
      if (value is String) {
        return value;
      } else if (value != null) {
        return value.toString();
      }
      return null;
    } catch (e) {
      print('⚠️ Error extracting string for key $key: $e');
      return null;
    }
  }

  /// Safely extract a number value from a Map
  num? _safeExtractNumber(Map properties, String key) {
    try {
      final value = properties[key];
      if (value is num) {
        return value;
      } else if (value is String) {
        return num.tryParse(value);
      } else if (value != null) {
        return num.tryParse(value.toString());
      }
      return null;
    } catch (e) {
      print('⚠️ Error extracting number for key $key: $e');
      return null;
    }
  }
}

/// Bottom sheet widget for displaying territory information
class _TerritoryInfoBottomSheet extends StatelessWidget {
  final Territory territory;
  final String ownerName;
  final String area;
  final String ownerId;

  const _TerritoryInfoBottomSheet({
    required this.territory,
    required this.ownerName,
    required this.area,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with territory icon and title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Territory icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTerritoryColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _getTerritoryColor(),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.place,
                    color: _getTerritoryColor(),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Territory Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Close button
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Territory information
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Owner information
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'Owner',
                  value: ownerName,
                  iconColor: Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                                 // Area information
                 _buildInfoRow(
                   icon: Icons.area_chart,
                   label: 'Area',
                   value: area,
                   iconColor: Colors.green,
                 ),
               ],
             ),
           ),
           
           const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTerritoryColor() {
    try {
      final userPrefs = Get.find<UserPreferencesService>();
      final databaseService = Get.find<DatabaseService>();
      final currentUserId = databaseService.currentUserId;
      
      if (territory.ownerId == currentUserId) {
        return userPrefs.userColor.value;
      } else if (territory.ownerColor != null && territory.ownerColor!.isNotEmpty) {
        try {
          String hexColor = territory.ownerColor!;
          if (hexColor.startsWith('#')) {
            hexColor = hexColor.substring(1);
          }
          if (hexColor.length == 6) {
            hexColor = 'FF$hexColor';
          }
          int colorValue = int.parse(hexColor, radix: 16);
          return Color(colorValue);
        } catch (e) {
          return Colors.grey;
        }
      } else {
        return Colors.grey;
      }
    } catch (e) {
      return Colors.grey;
    }
  }
}
