import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../models/territory/run_session_model.dart';
import '../../services/run_storage_service.dart';

class RunPathDisplayController extends GetxController {
  final RunStorageService _runStorageService = Get.find<RunStorageService>();

  // Observable state
  final RxBool isLoadingPaths = false.obs;
  final RxList<RunSession> displayedRunPaths = <RunSession>[].obs;
  final RxList<String> addedRunPathIds = <String>[].obs;

  // Map reference
  MapboxMap? _mapboxMap;

  // Configuration
  static const double maxRunPathDisplayDistance = 5000; // 5km max display
  static const int maxRunPathsToDisplay = 10; // Limit for performance

  @override
  void onInit() {
    super.onInit();
    print('🔧 RunPathDisplayController initialized');
    
    // Watch for run history changes
    ever(_runStorageService.recentRuns, (runs) {
      print('🔄 Run history changed: ${runs.length} runs');
      print('  Recent runs:');
      for (int i = 0; i < math.min(3, runs.length); i++) {
        var run = runs[i];
        print('    ${i+1}. ${run.id}: ${run.status}, ${run.distance?.toStringAsFixed(1)}m, ${run.rawPath.length} points');
      }
      if (_mapboxMap != null) {
        print('🗺️ Map available, refreshing run paths...');
        _refreshRunPathsFromCurrentLocation();
      } else {
        print('⚠️ Map not available yet, deferring refresh');
      }
    });
    
    // Initial refresh
    print('🔧 Performing initial run path refresh...');
    _refreshRunPathsFromCurrentLocation();
  }


  /// Initialize with map reference
  void initializeWithMap(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    print('🗺️ Map initialized in RunPathDisplayController');
    
    // Force refresh now that map is available
    print('🔄 Refreshing run paths now that map is available...');
    _refreshRunPathsFromCurrentLocation();
  }

  /// Refresh run paths based on current location
  Future<void> _refreshRunPathsFromCurrentLocation() async {
    try {
      // For now, display all completed runs with valid paths
      List<RunSession> completedRuns = _runStorageService.recentRuns
          .where((run) => 
            run.status == RunStatus.completed && 
            run.rawPath.isNotEmpty &&
            run.rawPath.length >= 2 // Need at least 2 points for a line
          )
          .take(maxRunPathsToDisplay)
          .toList();

      print('🗺️ Run paths to display: ${completedRuns.length}');
      for (RunSession run in completedRuns) {
        print('  - ${run.id}: ${run.rawPath.length} points, distance=${run.distance?.toStringAsFixed(1)}m');
      }

      displayedRunPaths.assignAll(completedRuns);

      // Update map display if map is available
      if (_mapboxMap != null) {
        await _updateRunPathsOnMap();
      }

      print('✅ Refreshed run paths: ${completedRuns.length} displayed');
    } catch (e) {
      print('❌ Error refreshing run paths: $e');
    } finally {
      isLoadingPaths.value = false;
    }
  }

  /// Update run paths display on map
  Future<void> _updateRunPathsOnMap() async {
    if (_mapboxMap == null) return;

    try {
      // Clear existing run path layers
      await _clearExistingRunPaths();

      // Add run paths to map
      for (RunSession runSession in displayedRunPaths) {
        await _addRunPathToMap(runSession);
      }

      print('✅ Updated ${displayedRunPaths.length} run paths on map');
    } catch (e) {
      print('❌ Error updating run paths on map: $e');
    }
  }

  /// Add single run path to map
  Future<void> _addRunPathToMap(RunSession runSession) async {
    if (_mapboxMap == null || runSession.rawPath.isEmpty) return;

    try {
      String sourceId = 'run-path-source-${runSession.id}';
      String lineLayerId = 'run-path-line-${runSession.id}';

      // Prepare coordinates for GeoJSON (Mapbox expects [lng, lat])
      List<List<double>> coordinates = runSession.rawPath.map((point) => 
        [point.longitude, point.latitude]
      ).toList();

      // Create GeoJSON for run path LineString
      String geoJsonData = '''
      {
        "type": "Feature",
        "properties": {
          "id": "${runSession.id}",
          "distance": ${runSession.distance ?? 0},
          "duration": ${runSession.duration?.inSeconds ?? 0}
        },
        "geometry": {
          "type": "LineString",
          "coordinates": ${coordinates.map((coord) => '[${coord[0]}, ${coord[1]}]').join(',')}
        }
      }
      ''';

      // Try to add source (skip if already exists)
      try {
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: sourceId,
          data: geoJsonData,
        ));
      } catch (e) {
        if (e.toString().contains('already exists')) {
          print('⚠️ Source $sourceId already exists, skipping...');
          return; // Skip this run path if source already exists
        } else {
          rethrow; // Re-throw if it's a different error
        }
      }

      // Determine line color based on run age
      Color lineColor = _getRunPathColor(runSession);
      double lineWidth = 5.0; // Increased from 3.0 for better visibility
      double lineOpacity = 0.9; // Increased from 0.7 for better visibility

      print('🗺️ Adding run path ${runSession.id} to map');
      print('🗺️ Run path: ${coordinates.length} points');
      print('🗺️ Computed color: $lineColor, width: $lineWidth, opacity: $lineOpacity');

      // Add line layer
      try {
        await _mapboxMap!.style.addLayer(LineLayer(
          id: lineLayerId,
          sourceId: sourceId,
          lineColor: _colorToInt(lineColor),
          lineWidth: lineWidth,
          lineOpacity: lineOpacity,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ));
        print('🗺️ ✅ Added line layer $lineLayerId');
      } catch (e) {
        if (e.toString().contains('already exists')) {
          print('⚠️ Layer $lineLayerId already exists, skipping...');
          return; // Skip if layer already exists
        } else {
          rethrow; // Re-throw if it's a different error
        }
      }

      addedRunPathIds.add(runSession.id);
      print('✅ Added run path ${runSession.id} to map');
    } catch (e) {
      print('❌ Error adding run path ${runSession.id} to map: $e');
    }
  }

  /// Get color for run path based on age
  Color _getRunPathColor(RunSession runSession) {
    DateTime now = DateTime.now();
    Duration age = now.difference(runSession.startTime);
    
    if (age.inDays < 1) {
      return Colors.green; // Recent runs are green
    } else if (age.inDays < 7) {
      return Colors.blue; // Week old runs are blue
    } else if (age.inDays < 30) {
      return Colors.orange; // Month old runs are orange
    } else {
      return Colors.grey; // Old runs are grey
    }
  }

  /// Clear existing run paths from map
  Future<void> _clearExistingRunPaths() async {
    if (_mapboxMap == null) return;

    try {
      // Make a copy to avoid concurrent modification
      List<String> idsToRemove = List.from(addedRunPathIds);
      
      for (String runId in idsToRemove) {
        String sourceId = 'run-path-source-$runId';
        String layerId = 'run-path-line-$runId';
        
        try {
          // Remove layer first, then source
          await _mapboxMap!.style.removeStyleLayer(layerId);
        } catch (e) {
          // Layer might not exist, continue
        }
        
        try {
          await _mapboxMap!.style.removeStyleSource(sourceId);
        } catch (e) {
          // Source might not exist, continue
        }
      }
      
      addedRunPathIds.clear();
      print('🧹 Cleared existing run paths');
    } catch (e) {
      print('❌ Error clearing existing run paths: $e');
    }
  }

  /// Convert Color to int for Mapbox
  int _colorToInt(Color color) {
    return (color.a.round() << 24) |
           (color.r.round() << 16) |
           (color.g.round() << 8) |
           color.b.round();
  }

  /// Manually refresh run paths
  Future<void> refreshRunPaths() async {
    print('🔄 Manual refresh run paths triggered');
    await _refreshRunPathsFromCurrentLocation();
  }

  /// Force refresh run paths (for debugging)
  Future<void> forceRefreshRunPaths() async {
    print('🔄 FORCE refresh run paths triggered');
    print('🔄 Available runs: ${_runStorageService.recentRuns.length}');
    
          for (RunSession run in _runStorageService.recentRuns) {
      print('  - Run ${run.id}: status=${run.status}, points=${run.rawPath.length}');
    }
    
    await _refreshRunPathsFromCurrentLocation();
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'displayed_run_paths': displayedRunPaths.length,
      'added_run_path_ids': addedRunPathIds.length,
      'map_initialized': _mapboxMap != null,
      'is_loading': isLoadingPaths.value,
    };
  }
}
