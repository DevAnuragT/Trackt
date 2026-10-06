import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/territory/territory_model.dart';
import '../../services/territory_service.dart';
import '../../services/location_service.dart';

enum ConflictType {
  overlap,
  adjacentClaim,
  encroachment,
  fullOverwrite
}

enum ConflictResolution {
  merge,
  split,
  priorityToOlder,
  priorityToLarger,
  priorityToActive
}

class TerritoryConflict {
  final String id;
  final List<Territory> conflictingTerritories;
  final ConflictType type;
  final double overlapPercentage;
  final DateTime detectedAt;
  final ConflictResolution? suggestedResolution;
  
  TerritoryConflict({
    required this.id,
    required this.conflictingTerritories,
    required this.type,
    required this.overlapPercentage,
    required this.detectedAt,
    this.suggestedResolution,
  });
}

class TerritoryConflictController extends GetxController {
  final TerritoryService _territoryService = Get.find<TerritoryService>();
  final LocationService _locationService = Get.find<LocationService>();

  // Observable state
  final RxList<TerritoryConflict> activeConflicts = <TerritoryConflict>[].obs;
  final RxList<TerritoryConflict> resolvedConflicts = <TerritoryConflict>[].obs;
  final RxBool isProcessingConflicts = false.obs;
  final RxInt totalConflictsDetected = 0.obs;

  // Configuration
  static const double minOverlapThreshold = 0.1; // 10% overlap triggers conflict
  static const double maxConflictResolutionTime = 300; // 5 minutes
  static const int maxConflictsPerCheck = 50;

  Timer? _conflictDetectionTimer;

  @override
  void onInit() {
    super.onInit();
    _startConflictDetection();
  }

  @override
  void onClose() {
    _conflictDetectionTimer?.cancel();
    super.onClose();
  }

  /// Start periodic conflict detection
  void _startConflictDetection() {
    _conflictDetectionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _detectTerritoryConflicts(),
    );
  }

  /// Detect territory conflicts in the current area
  Future<void> _detectTerritoryConflicts() async {
    if (isProcessingConflicts.value) return;

    try {
      isProcessingConflicts.value = true;

      final position = await _locationService.getHighAccuracyLocation();
      if (position == null) return;

      // Get all territories within a larger radius for conflict detection
      await _territoryService.fetchTerritoriesWithinRadius(
        centerLat: position.latitude,
        centerLng: position.longitude,
        radiusMeters: 5000, // 5km radius for conflict detection
      );
      
      final territories = _territoryService.nearbyTerritories.toList();

      final conflicts = await _analyzeForConflicts(territories);
      
      // Update active conflicts
      _updateActiveConflicts(conflicts);
      
      // Process automatic resolutions
      await _processAutomaticResolutions();

      print('🔍 Detected ${conflicts.length} territory conflicts');
      
    } catch (e) {
      print('❌ Error detecting conflicts: $e');
    } finally {
      isProcessingConflicts.value = false;
    }
  }

  /// Analyze territories for potential conflicts
  Future<List<TerritoryConflict>> _analyzeForConflicts(List<Territory> territories) async {
    final conflicts = <TerritoryConflict>[];
    
    for (int i = 0; i < territories.length; i++) {
      for (int j = i + 1; j < territories.length; j++) {
        final territory1 = territories[i];
        final territory2 = territories[j];
        
        // Skip if same user
        if (territory1.ownerId == territory2.ownerId) continue;
        
        final conflict = await _checkTerritoryConflict(territory1, territory2);
        if (conflict != null) {
          conflicts.add(conflict);
        }
      }
    }
    
    return conflicts;
  }

  /// Check if two territories have a conflict
  Future<TerritoryConflict?> _checkTerritoryConflict(Territory t1, Territory t2) async {
    final overlapArea = _calculateOverlapArea(t1, t2);
    final t1Area = _calculateTerritoryArea(t1);
    final t2Area = _calculateTerritoryArea(t2);
    
    if (overlapArea <= 0) return null;
    
    final overlapPercentage = overlapArea / math.min(t1Area, t2Area);
    
    if (overlapPercentage < minOverlapThreshold) return null;
    
    ConflictType type;
    if (overlapPercentage > 0.8) {
      type = ConflictType.fullOverwrite;
    } else if (overlapPercentage > 0.3) {
      type = ConflictType.overlap;
    } else if (_areTerritoriesAdjacent(t1, t2)) {
      type = ConflictType.adjacentClaim;
    } else {
      type = ConflictType.encroachment;
    }
    
    final suggestedResolution = _suggestResolution(t1, t2, type, overlapPercentage);
    
    return TerritoryConflict(
      id: '${t1.id}_${t2.id}_${DateTime.now().millisecondsSinceEpoch}',
      conflictingTerritories: [t1, t2],
      type: type,
      overlapPercentage: overlapPercentage,
      detectedAt: DateTime.now(),
      suggestedResolution: suggestedResolution,
    );
  }

  /// Calculate overlap area between two territories using shoelace formula
  double _calculateOverlapArea(Territory t1, Territory t2) {
    // Simple bounding box overlap check first
    final t1Bounds = _getTerritoryBounds(t1);
    final t2Bounds = _getTerritoryBounds(t2);
    
    if (!_boundsOverlap(t1Bounds, t2Bounds)) return 0.0;
    
    // For more accurate overlap, we'd need polygon intersection algorithms
    // For now, approximate using bounding box overlap
    final overlapBounds = _getOverlapBounds(t1Bounds, t2Bounds);
    if (overlapBounds == null) return 0.0;
    
    return _calculateBoundsArea(overlapBounds);
  }

  /// Calculate territory area using shoelace formula
  double _calculateTerritoryArea(Territory territory) {
    if (territory.boundaryPoints.length < 3) return 0.0;
    
    double area = 0.0;
    final points = territory.boundaryPoints;
    
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += points[i].latitude * points[j].longitude;
      area -= points[j].latitude * points[i].longitude;
    }
    
    return (area.abs() / 2.0) * 111000 * 111000; // Convert to square meters
  }

  /// Get territory bounding box
  Map<String, double> _getTerritoryBounds(Territory territory) {
    if (territory.boundaryPoints.isEmpty) {
      return {'minLat': 0, 'maxLat': 0, 'minLng': 0, 'maxLng': 0};
    }
    
    double minLat = territory.boundaryPoints.first.latitude;
    double maxLat = territory.boundaryPoints.first.latitude;
    double minLng = territory.boundaryPoints.first.longitude;
    double maxLng = territory.boundaryPoints.first.longitude;
    
    for (final point in territory.boundaryPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  /// Check if two bounding boxes overlap
  bool _boundsOverlap(Map<String, double> bounds1, Map<String, double> bounds2) {
    return bounds1['minLat']! <= bounds2['maxLat']! &&
           bounds1['maxLat']! >= bounds2['minLat']! &&
           bounds1['minLng']! <= bounds2['maxLng']! &&
           bounds1['maxLng']! >= bounds2['minLng']!;
  }

  /// Get overlap area between two bounding boxes
  Map<String, double>? _getOverlapBounds(Map<String, double> bounds1, Map<String, double> bounds2) {
    final minLat = math.max(bounds1['minLat']!, bounds2['minLat']!);
    final maxLat = math.min(bounds1['maxLat']!, bounds2['maxLat']!);
    final minLng = math.max(bounds1['minLng']!, bounds2['minLng']!);
    final maxLng = math.min(bounds1['maxLng']!, bounds2['maxLng']!);
    
    if (minLat >= maxLat || minLng >= maxLng) return null;
    
    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  /// Calculate area of bounding box
  double _calculateBoundsArea(Map<String, double> bounds) {
    final latDiff = bounds['maxLat']! - bounds['minLat']!;
    final lngDiff = bounds['maxLng']! - bounds['minLng']!;
    return latDiff * lngDiff * 111000 * 111000; // Convert to square meters
  }

  /// Check if territories are adjacent (simplified)
  bool _areTerritoriesAdjacent(Territory t1, Territory t2) {
    // Simplified adjacency check using distance between centroids
    final t1Center = _getTerritoryCenter(t1);
    final t2Center = _getTerritoryCenter(t2);
    
    final distance = _calculateDistance(
      t1Center['lat']!,
      t1Center['lng']!,
      t2Center['lat']!,
      t2Center['lng']!,
    );
    
    return distance <= 100; // 100 meters
  }

  /// Get territory center point
  Map<String, double> _getTerritoryCenter(Territory territory) {
    if (territory.boundaryPoints.isEmpty) return {'lat': 0, 'lng': 0};
    
    double latSum = 0, lngSum = 0;
    for (final point in territory.boundaryPoints) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }
    
    return {
      'lat': latSum / territory.boundaryPoints.length,
      'lng': lngSum / territory.boundaryPoints.length,
    };
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth radius in meters
    
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Suggest resolution for territory conflict
  ConflictResolution _suggestResolution(Territory t1, Territory t2, ConflictType type, double overlapPercentage) {
    switch (type) {
      case ConflictType.fullOverwrite:
        // Priority to older territory
        return t1.createdAt.isBefore(t2.createdAt) 
            ? ConflictResolution.priorityToOlder 
            : ConflictResolution.priorityToOlder;
      
      case ConflictType.overlap:
        if (overlapPercentage > 0.5) {
          return ConflictResolution.merge;
        } else {
          return ConflictResolution.split;
        }
      
      case ConflictType.adjacentClaim:
        return ConflictResolution.merge;
      
      case ConflictType.encroachment:
        return ConflictResolution.priorityToLarger;
    }
  }

  /// Update active conflicts list
  void _updateActiveConflicts(List<TerritoryConflict> newConflicts) {
    // Remove old conflicts
    activeConflicts.removeWhere((conflict) {
      final age = DateTime.now().difference(conflict.detectedAt).inSeconds;
      return age > maxConflictResolutionTime;
    });
    
    // Add new conflicts (avoid duplicates)
    for (final conflict in newConflicts) {
      final existingIndex = activeConflicts.indexWhere((existing) {
        return existing.conflictingTerritories.length == conflict.conflictingTerritories.length &&
               existing.conflictingTerritories.every((t1) =>
                 conflict.conflictingTerritories.any((t2) => t1.id == t2.id));
      });
      
      if (existingIndex == -1) {
        activeConflicts.add(conflict);
        totalConflictsDetected.value++;
      }
    }
  }

  /// Process automatic conflict resolutions
  Future<void> _processAutomaticResolutions() async {
    final autoResolvable = activeConflicts.where((conflict) =>
      conflict.suggestedResolution != null &&
      conflict.type != ConflictType.fullOverwrite &&
      conflict.overlapPercentage < 0.3
    ).toList();
    
    for (final conflict in autoResolvable) {
      try {
        await _resolveConflict(conflict, conflict.suggestedResolution!);
        activeConflicts.remove(conflict);
        resolvedConflicts.add(conflict);
        
        print('✅ Auto-resolved conflict: ${conflict.id}');
      } catch (e) {
        print('❌ Failed to auto-resolve conflict ${conflict.id}: $e');
      }
    }
  }

  /// Resolve a territory conflict
  Future<void> _resolveConflict(TerritoryConflict conflict, ConflictResolution resolution) async {
    switch (resolution) {
      case ConflictResolution.merge:
        await _mergeTerritories(conflict.conflictingTerritories);
        break;
      
      case ConflictResolution.split:
        await _splitTerritories(conflict.conflictingTerritories);
        break;
      
      case ConflictResolution.priorityToOlder:
        await _prioritizeOlderTerritory(conflict.conflictingTerritories);
        break;
      
      case ConflictResolution.priorityToLarger:
        await _prioritizeLargerTerritory(conflict.conflictingTerritories);
        break;
      
      case ConflictResolution.priorityToActive:
        await _prioritizeActiveTerritory(conflict.conflictingTerritories);
        break;
    }
  }

  /// Merge conflicting territories
  Future<void> _mergeTerritories(List<Territory> territories) async {
    // Implementation would merge territory boundaries
    // For now, just log the action
    print('🔄 Merging territories: ${territories.map((t) => t.id).join(', ')}');
  }

  /// Split overlapping territories
  Future<void> _splitTerritories(List<Territory> territories) async {
    // Implementation would split overlapping areas
    // For now, just log the action
    print('✂️ Splitting territories: ${territories.map((t) => t.id).join(', ')}');
  }

  /// Give priority to older territory
  Future<void> _prioritizeOlderTerritory(List<Territory> territories) async {
    territories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final winner = territories.first;
    final losers = territories.skip(1).toList();
    
    print('👑 Priority to older territory: ${winner.id}');
    print('❌ Removing territories: ${losers.map((t) => t.id).join(', ')}');
  }

  /// Give priority to larger territory
  Future<void> _prioritizeLargerTerritory(List<Territory> territories) async {
    territories.sort((a, b) => _calculateTerritoryArea(b).compareTo(_calculateTerritoryArea(a)));
    final winner = territories.first;
    final losers = territories.skip(1).toList();
    
    print('👑 Priority to larger territory: ${winner.id}');
    print('❌ Removing territories: ${losers.map((t) => t.id).join(', ')}');
  }

  /// Give priority to more active territory
  Future<void> _prioritizeActiveTerritory(List<Territory> territories) async {
    // For now, use most recent activity (createdAt since we don't have updatedAt)
    territories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final winner = territories.first;
    final losers = territories.skip(1).toList();
    
    print('👑 Priority to active territory: ${winner.id}');
    print('❌ Removing territories: ${losers.map((t) => t.id).join(', ')}');
  }

  /// Manual conflict resolution by user
  Future<void> manualResolveConflict(String conflictId, ConflictResolution resolution) async {
    final conflict = activeConflicts.firstWhereOrNull((c) => c.id == conflictId);
    if (conflict == null) return;
    
    try {
      await _resolveConflict(conflict, resolution);
      activeConflicts.remove(conflict);
      resolvedConflicts.add(conflict);
      
      Get.snackbar(
        'Conflict Resolved',
        'Territory conflict has been resolved successfully',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      Get.snackbar(
        'Resolution Failed',
        'Failed to resolve territory conflict: $e',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Get conflict summary for UI
  Map<String, dynamic> get conflictSummary => {
    'active': activeConflicts.length,
    'resolved': resolvedConflicts.length,
    'total': totalConflictsDetected.value,
    'processing': isProcessingConflicts.value,
  };
}
