import 'dart:async';
// import 'dart:convert';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' as geo;
// import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/territory/territory_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../views/map/components/bottom_sheet_widget.dart';
// import 'dart:math' as math;

class TerritoryService extends GetxService {
  final DatabaseService _databaseService = DatabaseService();
  // final LocalStorageService _localStorageService = LocalStorageService(); // Temporarily disabled
  late final LocationService _locationService;

  // Reactive variables
  final RxList<Territory> nearbyTerritories = <Territory>[].obs;
  final RxList<Territory> userTerritories = <Territory>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isOfflineMode = false.obs;
  final RxInt cachedTerritoriesCount = 0.obs;

  // Smart Sync Components
  final RxList<Territory> pendingTerritoryUploads = <Territory>[].obs;
  final RxBool isSyncing = false.obs;
  DateTime? lastSyncTimestamp;

  // Configuration
  static const int defaultRadiusMeters = 3000; // 3km radius
  static const Duration cacheValidityDuration = Duration(hours: 1);
  
  // ==================== LOCAL PERSISTENCE ====================

  /// Add a new territory to user's territory list (assumes already uploaded to cloud)
  Future<void> addUserTerritory(Territory territory) async {
    try {
      print('🗺️ Adding territory to user territories list: ${territory.id}');
      print('🗺️ Note: Territory should already be uploaded to cloud by caller');
      
      // Add to reactive list
      userTerritories.add(territory);
      
      // Update user statistics after territory addition
      try {
        // Force recompute all statistics to ensure consistency with server
        await _databaseService.recomputeUserStatistics(territory.ownerId);
        print('✅ User statistics recomputed after territory addition');
        
        // Refresh bottom sheet statistics if available
        try {
          if (Get.isRegistered<BottomSheetController>()) {
            final bottomSheetController = Get.find<BottomSheetController>();
            bottomSheetController.forceRefreshStatistics();
          }
        } catch (e) {
          print('⚠️ Could not refresh bottom sheet: $e');
        }
      } catch (e) {
        print('⚠️ Warning: Failed to recompute user statistics: $e');
        // Don't fail territory addition if stats update fails
      }
      
      print('✅ Territory added to user territories successfully');
    } catch (e) {
      print('❌ Error adding territory to user territories: $e');
    }
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    
    // Initialize location service
    _locationService = Get.find<LocationService>();
    
    // Load sync-related data
    // await _loadPendingUploads();
    // await _loadLastSyncTimestamp();
    
    // Test database connection
    bool isConnected = await _databaseService.testConnection();
    isOfflineMode.value = !isConnected;
    
    print('✅ TerritoryService initialized (${isConnected ? 'Online' : 'Offline'})');
    
    // Auto-sync if online and have pending uploads
    if (isConnected && pendingTerritoryUploads.isNotEmpty) {
      print('🔄 Auto-syncing ${pendingTerritoryUploads.length} pending territories...');
      // Note: syncPendingTerritoryUploads method was removed, territories are synced automatically
    }
  }

  @override
  void onClose() {
    // Note: Network monitoring was removed
    super.onClose();
  }

  // ==================== TERRITORY MANAGEMENT ====================

  /// Fetch territories within a custom radius of a given center point
  /// and update the nearbyTerritories list.
  Future<void> fetchTerritoriesWithinRadius({
    required double centerLat,
    required double centerLng,
    int radiusMeters = defaultRadiusMeters,
  }) async {
    if (isOfflineMode.value) {
      print('📱 Cannot fetch territories within radius in offline mode');
      return;
    }

    try {
      isLoading.value = true;

      final territories = await _databaseService.getTerritoriesWithinRadius(
        centerLat: centerLat,
        centerLng: centerLng,
        radiusMeters: radiusMeters,
      );

      nearbyTerritories
        ..clear()
        ..addAll(territories);

      print('✅ Fetched ${territories.length} territories within ${radiusMeters}m');
    } catch (e) {
      print('❌ Error fetching territories within radius: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh nearby territories from database
  Future<void> refreshNearbyTerritories() async {
    if (isOfflineMode.value) return;
    
    try {
      isLoading.value = true;
      
      // Get current user location
      final currentPosition = _locationService.currentPosition.value;
      if (currentPosition == null) {
        print('⚠️ No current position available for territory refresh');
        return;
      }
      
      // Fetch territories within radius
      List<Territory> territories = await _databaseService.getTerritoriesWithinRadius(
        centerLat: currentPosition.latitude,
        centerLng: currentPosition.longitude,
        radiusMeters: defaultRadiusMeters,
      );
      
      // Update reactive list
      nearbyTerritories.clear();
      nearbyTerritories.addAll(territories);
      
      print('✅ Refreshed nearby territories: ${territories.length} found');
      
    } catch (e) {
      print('❌ Error refreshing nearby territories: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh nearby territories for map display with proper layering
  Future<void> refreshNearbyTerritoriesForMapDisplay() async {
    if (isOfflineMode.value) return;
    
    try {
      isLoading.value = true;
      
      // Get current user location
      geo.Position? currentPosition = _locationService.currentPosition.value;
      print('🔍 Location service current position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
      
      if (currentPosition == null) {
        print('⚠️ No current position available for map territory refresh');
        print('🔍 Trying to get location from location service...');
        
        // Try to get location manually
        try {
          print('🔍 Forcing location refresh...');
          await _locationService.refreshCurrentLocation();
          
          final position = _locationService.currentPosition.value;
          if (position != null) {
            print('✅ Got position after refresh: ${position.latitude}, ${position.longitude}');
            currentPosition = position;
          } else {
            print('❌ Still no position available, using fallback coordinates');
            // Use fallback coordinates (London) for testing
            currentPosition = geo.Position(
              latitude: 51.5074,
              longitude: -0.1276,
              timestamp: DateTime.now(),
              accuracy: 100.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
          }
        } catch (e) {
          print('❌ Error getting position manually: $e');
          return;
        }
      }
      
      // Fetch territories for map display with proper layering logic
      List<Territory> territories = await _databaseService.getTerritoriesForMapDisplay(
        centerLat: currentPosition.latitude,
        centerLng: currentPosition.longitude,
        radiusMeters: defaultRadiusMeters,
      );
      
      // Update reactive list
      nearbyTerritories.clear();
      nearbyTerritories.addAll(territories);
      
      print('✅ Refreshed nearby territories for map display: ${territories.length} found with proper layering');
      
      // Cache the results locally
      // await _cacheNearbyTerritories(territories);
      
    } catch (e) {
      print('❌ Error refreshing nearby territories for map display: $e');
      // Fallback to regular refresh if the specialized one fails
      print('🔄 Falling back to regular territory refresh...');
      await refreshNearbyTerritories();
    } finally {
      isLoading.value = false;
    }
  }

  /// Get user's own territories
  Future<void> fetchUserTerritories() async {
    try {
      if (isOfflineMode.value) {
        print('📱 Cannot fetch user territories in offline mode');
        return;
      }

      List<Territory> territories = await _databaseService.getUserTerritories();
      userTerritories.assignAll(territories);
      
      print('✅ Fetched ${territories.length} user territories');
    } catch (e) {
      print('❌ Error fetching user territories: $e');
    }
  }

  // ==================== USER PROFILE & STATISTICS ====================

  /// Update user profile
  Future<bool> updateUserProfile({
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      if (isOfflineMode.value) {
        print('📱 Cannot update profile in offline mode');
        return false;
      }

      await _databaseService.upsertUserProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );

      return true;
    } catch (e) {
      print('❌ Error updating user profile: $e');
      return false;
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>?> getUserStatistics([String? userId]) async {
    try {
      String? targetUserId = userId ?? _databaseService.currentUserId;
      if (targetUserId == null) return null;

      // Try to get from cache first
      // Map<String, dynamic>? cachedStats = await _localStorageService.getCachedUserStatistics(targetUserId); // Temporarily disabled
      Map<String, dynamic>? cachedStats;
      
      if (!isOfflineMode.value) {
        // Fetch fresh data from cloud
        Map<String, dynamic>? cloudStats = await _databaseService.getUserStatistics(userId);
        
        if (cloudStats != null) {
          // Cache the fresh data
          // await _localStorageService.cacheUserStatistics(targetUserId, cloudStats); // Temporarily disabled
          return cloudStats;
        }
      }

      // Return cached data if available
      return cachedStats;
    } catch (e) {
      print('❌ Error getting user statistics: $e');
      return null;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check and update online status
  Future<void> checkOnlineStatus() async {
    bool isConnected = await _databaseService.testConnection();
    isOfflineMode.value = !isConnected;
  }

  /// Get territories for map display (both own and others)
  List<Territory> get allDisplayTerritories => nearbyTerritories.toList();

  /// Get only other users' territories
  List<Territory> get otherUsersTerritories {
    String? currentUserId = _databaseService.currentUserId;
    if (currentUserId == null) return nearbyTerritories.toList();
    return nearbyTerritories.where((t) => t.ownerId != currentUserId).toList();
  }

  /// Get only current user's territories from nearby list
  List<Territory> get nearbyOwnTerritories {
    String? currentUserId = _databaseService.currentUserId;
    if (currentUserId == null) return [];
    return nearbyTerritories.where((t) => t.ownerId == currentUserId).toList();
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _databaseService.isAuthenticated;

  /// Get current user ID
  String? get currentUserId => _databaseService.currentUserId;

  // Conquest system removed: all methods stubbed
  Future<bool> wouldConquerTerritories(List<Map<String, dynamic>> runBoundaryPoints) async { return false; }
  Future<List<Map<String, dynamic>>> getConquestPreview(List<Map<String, dynamic>> runBoundaryPoints) async { return []; }
  Future<List<Map<String, dynamic>>> executeTerritoryConquest(List<Map<String, dynamic>> runBoundaryPoints, String newOwnerId) async { return []; }

  /// Refresh territory data from database after conquests
  Future<void> refreshTerritoryData() async {
    try {
      // Refresh user territories
      await _loadUserTerritoriesFromDatabase();
      
      // Refresh nearby territories
      await refreshNearbyTerritories();
      
      print('🔄 Territory data refreshed after conquest');
    } catch (e) {
      print('❌ Error refreshing territory data: $e');
    }
  }

  /// Load user territories from database (for conquest updates)
  Future<void> _loadUserTerritoriesFromDatabase() async {
    try {
      final territories = await _databaseService.getUserTerritories();
      
      // Update reactive list
      userTerritories.clear();
      userTerritories.addAll(territories);
      print('📱 Loaded ${territories.length} user territories from database');
    } catch (e) {
      print('❌ Error loading user territories from database: $e');
    }
  }

  // ==================== TERRITORY MANAGEMENT ====================

  /// Get all territories for territory history page
  List<Territory> getAllTerritories() {
    return allDisplayTerritories.toList();
  }
  
  /// Get all territories asynchronously (refreshes from database)
  Future<List<Territory>> getAllTerritoriesAsync() async {
    await refreshTerritoryData();
    return allDisplayTerritories.toList();
  }

  /// Refresh nearby territories for a specific location (when camera moves to new area)
  Future<void> refreshNearbyTerritoriesForLocation(double latitude, double longitude) async {
    if (isOfflineMode.value) return;
    
    try {
      isLoading.value = true;
      
      print('🔍 Refreshing territories for new camera location: $latitude, $longitude');
      
      // Fetch territories for the new location with proper layering logic
      List<Territory> territories = await _databaseService.getTerritoriesForMapDisplay(
        centerLat: latitude,
        centerLng: longitude,
        radiusMeters: defaultRadiusMeters,
      );
      
      // Update reactive list
      nearbyTerritories.clear();
      nearbyTerritories.addAll(territories);
      
      print('✅ Refreshed territories for new location: ${territories.length} found at $latitude, $longitude');
      
      // Don't cache territories for different locations - only keep current view
      // This prevents accumulating data from every place the user visits on the map
      
    } catch (e) {
      print('❌ Error refreshing territories for new location: $e');
      // Fallback to regular refresh if the specialized one fails
      print('🔄 Falling back to regular territory refresh...');
      await refreshNearbyTerritories();
    } finally {
      isLoading.value = false;
    }
  }

}
