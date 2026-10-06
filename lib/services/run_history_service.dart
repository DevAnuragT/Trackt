import 'package:get/get.dart';
import '../models/territory/territory_model.dart';
import '../services/database_service.dart';
import 'dart:math' as math;

/// Service for managing user territories from Supabase
/// Used for displaying territories in bottom sheet and territory history page
class TerritoryHistoryService extends GetxService {
  static const int _maxRecentCount = 10; // Keep only recent 10 territories in bottom sheet
  
  // Database service for fetching territories
  final DatabaseService _databaseService = DatabaseService();
  
  // Observable list of recent territories (for bottom sheet)
  final RxList<Territory> recentTerritories = <Territory>[].obs;
  
  // Observable list of all territories (for territory history page)
  final RxList<Territory> allTerritories = <Territory>[].obs;
  
  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadTerritories();
  }
  
  /// Load user territories from Supabase
  Future<void> loadTerritories() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      
      print('🗺️ Loading user territories from Supabase...');
      
      // Fetch all user territories from database
      List<Territory> territories = await _databaseService.getUserTerritories();
      
      // Update all territories list
      allTerritories.clear();
      allTerritories.addAll(territories);
      
      // Update recent territories (most recent 10)
      recentTerritories.clear();
      if (territories.isNotEmpty) {
        // Sort territories by creation date (newest first)
        final sortedTerritories = List<Territory>.from(territories);
        sortedTerritories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Take the 10 most recent territories
        if (sortedTerritories.length > _maxRecentCount) {
          recentTerritories.addAll(sortedTerritories.take(_maxRecentCount));
        } else {
          recentTerritories.addAll(sortedTerritories);
        }
      }
      
      print('✅ Loaded ${allTerritories.length} total territories, ${recentTerritories.length} recent');
    } catch (e) {
      print('❌ Error loading territories: $e');
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Refresh territories (called after conquests or new territory creation)
  Future<void> refreshTerritories() async {
    print('🔄 Refreshing territories...');
    await loadTerritories();
  }
  
  /// Get all territories for territory history page
  List<Territory> getAllTerritories() {
    return allTerritories.toList();
  }
  
  /// Get recent territories for bottom sheet
  List<Territory> getRecentTerritories() {
    return recentTerritories.toList();
  }
  
  /// Get territory statistics
  Map<String, dynamic> getTerritoryStats() {
    if (allTerritories.isEmpty) {
      return {
        'totalTerritories': 0,
        'totalArea': 0.0,
        'averageArea': 0.0,
        'largestTerritory': 0.0,
        'smallestTerritory': 0.0,
      };
    }
    
    final totalArea = allTerritories.fold<double>(
      0.0, (sum, territory) => sum + territory.area
    );
    
    final areas = allTerritories.map((t) => t.area).toList();
    areas.sort();
    
    return {
      'totalTerritories': allTerritories.length,
      'totalArea': totalArea,
      'averageArea': totalArea / allTerritories.length,
      'largestTerritory': areas.last,
      'smallestTerritory': areas.first,
    };
  }
  
  /// Format area for display
  String formatArea(double area) {
    // area is in square meters
    return '${(area / 1000000).toStringAsFixed(2)} km²';
  }
  
  /// Format date for display
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  /// Get territories by date range
  List<Territory> getTerritoriesByDateRange(DateTime start, DateTime end) {
    return allTerritories.where((territory) => 
      territory.createdAt.isAfter(start) && territory.createdAt.isBefore(end)
    ).toList();
  }
  
  /// Get territories by area range
  List<Territory> getTerritoriesByAreaRange(double minArea, double maxArea) {
    return allTerritories.where((territory) => 
      territory.area >= minArea && territory.area <= maxArea
    ).toList();
  }
  
  /// Search territories by location (near a point)
  List<Territory> getTerritoriesNearLocation(double lat, double lng, double radiusKm) {
    return allTerritories.where((territory) {
      final distance = _calculateDistance(
        lat, lng, 
        territory.center.latitude, territory.center.longitude
      );
      return distance <= radiusKm;
    }).toList();
  }
  
  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}