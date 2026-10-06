import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/territory/territory_model.dart';
import '../models/territory/steal_event_model.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== TERRITORIES ====================

  /// Upload territory to Supabase with timeout and retry
  Future<String?> uploadTerritory(Territory territory) async {
    const maxRetries = 3;
    const timeoutDuration = Duration(seconds: 30);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          print('❌ Territory upload failed: User not authenticated');
          throw Exception('User not authenticated');
        }

        // Ensure user profile exists before uploading territory
        print('👤 Ensuring user profile exists for: ${user.id}');
        try {
          await _supabase.rpc('create_user_profile_if_not_exists', params: {
            'user_id': user.id,
            'email': user.email ?? 'user@example.com', // Use user's email or fallback
            'display_name': user.userMetadata?['full_name'] ?? 'User ${user.id}',
            'user_color': '#3B82F6', // Default blue color
          }).timeout(timeoutDuration);
          print('✅ User profile ensured');
        } catch (profileError) {
          print('⚠️ Warning: Could not ensure user profile: $profileError');
          print('🔄 Continuing with territory upload - profile will be created automatically if needed');
        }

        print('🚀 Starting territory upload to Supabase (attempt $attempt/$maxRetries)...');
        print('📍 Territory ID: ${territory.id}');
        print('👤 User ID: ${user.id}');
        print('📏 Territory area: ${territory.area}');

        // Calculate center point for the territory
        final centerLat = territory.center.latitude;
        final centerLng = territory.center.longitude;

        // Prepare boundary points for upload (simplified format for PostGIS)
        final boundaryPointsJson = territory.boundaryPoints.map((point) => {
          'lat': point.latitude,
          'lng': point.longitude,
        }).toList();

        print('🗺️ Uploading territory with ${boundaryPointsJson.length} boundary points');
        print('📍 First point: ${boundaryPointsJson.first}');
        print('📍 Last point: ${boundaryPointsJson.last}');
        print('📍 Points match: ${boundaryPointsJson.first == boundaryPointsJson.last}');

        // Use the new RPC function for territory insertion
        print('🗺️ Calling insert_territory RPC with parameters:');
        print('🗺️ - p_owner_id: ${user.id} (${user.id.runtimeType})');
        print('🗺️ - boundary_points: ${boundaryPointsJson.length} points');
        print('🗺️ - area: ${territory.area} (${territory.area.runtimeType})');
        print('🗺️ - center_lat: $centerLat (${centerLat.runtimeType})');
        print('🗺️ - center_lng: $centerLng (${centerLng.runtimeType})');
        print('🗺️ - owner_color: ${territory.ownerColor ?? '#3B82F6'}');
        print('🗺️ - merge_distance_meters: 50.0');
        
        final response = await _supabase.rpc('insert_territory', params: {
          'p_owner_id': user.id,
          'boundary_points': boundaryPointsJson,
          'area': territory.area, // This will be overridden by PostGIS calculation
          'center_lat': centerLat,
          'center_lng': centerLng,
          'owner_color': territory.ownerColor ?? '#3B82F6',
          'merge_distance_meters': 50.0,
        }).timeout(timeoutDuration);

        print('✅ Territory uploaded successfully on attempt $attempt: $response');
        return response.toString();
      } catch (e) {
        print('❌ Error uploading territory (attempt $attempt/$maxRetries): $e');
        
        if (e.toString().contains('relation "territories" does not exist')) {
          print('🔧 Hint: Run the database cleanup script to create the territories table');
          rethrow; // Don't retry if table doesn't exist
        }
        
        if (attempt < maxRetries && !e.toString().contains('duplicate key')) {
          print('🔄 Retrying territory upload in ${attempt * 2} seconds...');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        
        rethrow;
      }
    }
    
    throw Exception('Territory upload failed after $maxRetries attempts');
  }

  /// Get territories within radius from a point (with owner colors)
  Future<List<Territory>> getTerritoriesWithinRadius({
    required double centerLat,
    required double centerLng,
    int radiusMeters = 3000,
  }) async {
    try {
      // Use PostGIS function to get territories within radius
      final response = await _supabase.rpc('get_territories_within_radius', params: {
        'search_center_lat': centerLat,
        'search_center_lng': centerLng,
        'radius_meters': radiusMeters,
      });

      // Get territories with basic info
      List<Territory> territories = response.map<Territory>((json) {
        final territoryJson = {
          'id': json['id'],
          'owner_id': json['owner_id'],
          'boundary_points': json['boundary_points'], // Don't double-encode!
          'area': json['area'],
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'center_lat': json['center_lat'],
          'center_lng': json['center_lng'],
        };
        return Territory.fromJson(territoryJson);
      }).toList();

      // Fetch owner colors for all territories
      await _enrichTerritoriesWithOwnerColors(territories);
      
      return territories;
    } catch (e) {
      print('❌ Error fetching territories within radius: $e');
      return [];
    }
  }

  /// Fetch territories for map display with proper layering logic
  Future<List<Territory>> getTerritoriesForMapDisplay({
    required double centerLat,
    required double centerLng,
    int radiusMeters = 3000,
  }) async {
    try {
      // Use the specialized function for map display with proper layering
      final response = await _supabase.rpc('get_territories_for_map_display', params: {
        'search_center_lat': centerLat,
        'search_center_lng': centerLng,
        'radius_meters': radiusMeters,
      });

      // Get territories with enhanced info including render layer
      List<Territory> territories = response.map<Territory>((json) {
        print('🔍 Database response for territory ${json['id']}: boundary_points type: ${json['boundary_points']?.runtimeType}, length: ${json['boundary_points']?.length ?? 0}');
        
        final territoryJson = {
          'id': json['id'],
          'owner_id': json['owner_id'],
          'boundary_points': json['boundary_points'], // Don't double-encode!
          'area': json['area'],
          'created_at': DateTime.parse(json['created_at']).millisecondsSinceEpoch,
          'center_lat': json['center_lat'],
          'center_lng': json['center_lng'],
          'render_layer': json['render_layer'], // Include render layer for proper ordering
          'is_conquered': json['is_conquered'], // Include conquest status
        };
        
        final territory = Territory.fromJson(territoryJson);
        print('🔍 Parsed territory ${territory.id}: boundaryRings: ${territory.boundaryRings?.length ?? 0}, boundaryPoints: ${territory.boundaryPoints.length}');
        return territory;
      }).toList();

      // Sort by render layer to ensure proper layering
      territories.sort((a, b) => (a.renderLayer ?? 0).compareTo(b.renderLayer ?? 0));

      // Fetch owner colors for all territories
      await _enrichTerritoriesWithOwnerColors(territories);
      
      print('✅ Fetched ${territories.length} territories for map display with proper layering');
      return territories;
    } catch (e) {
      print('❌ Error fetching territories for map display: $e');
      // Fallback to regular function if the specialized one fails
      print('🔄 Falling back to regular territories function...');
      return getTerritoriesWithinRadius(
        centerLat: centerLat,
        centerLng: centerLng,
        radiusMeters: radiusMeters,
      );
    }
  }

  // Steal notifications removed
  Future<List<StealEvent>> getStealEventsForCurrentUser() async { return []; }

  Future<List<Map<String, dynamic>>> getRecentStealEvents() async { return []; }
  
  Future<List<Map<String, dynamic>>> getUserConquests() async { return []; }
  
  Future<List<Map<String, dynamic>>> getUserTerritoryLosses() async { return []; }

  
  /// Enrich territories with owner colors from user profiles
  Future<void> _enrichTerritoriesWithOwnerColors(List<Territory> territories) async {
    if (territories.isEmpty) return;
    
    try {
      // Get unique owner IDs
      Set<String> ownerIds = territories.map((t) => t.ownerId).toSet();
      
      // Fetch user colors for all owners
      final userProfilesResponse = await _supabase
          .from('user_profiles')
          .select('id, user_color')
          .inFilter('id', ownerIds.toList());
      
      // Create a map of user ID to color
      Map<String, String> userColors = {};
      for (var profile in userProfilesResponse) {
        userColors[profile['id']] = profile['user_color'] ?? '#3B82F6';
      }
      
      // Update territories with owner colors
      for (int i = 0; i < territories.length; i++) {
        var territory = territories[i];
        
        // Debug: Log territory data before enrichment
        print('🔍 Enriching territory ${territory.id}: area=${territory.area}, center=${territory.center.latitude},${territory.center.longitude}');
        
        // Create a new territory with owner color, preserving boundaryRings
        territories[i] = Territory(
          id: territory.id,
          ownerId: territory.ownerId,
          boundaryPoints: territory.boundaryPoints,
          boundaryRings: territory.boundaryRings, // Preserve the ring structure!
          area: territory.area,
          createdAt: territory.createdAt,
          center: territory.center,
          ownerColor: userColors[territory.ownerId],
          renderLayer: territory.renderLayer, // Preserve render layer
          isConquered: territory.isConquered, // Preserve conquest status
        );
      }
      
      print('✅ Enriched ${territories.length} territories with owner colors');
    } catch (e) {
      print('❌ Error enriching territories with owner colors: $e');
    }
  }

  /// Get user's own territories (with owner colors)
  Future<List<Territory>> getUserTerritories() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('territories')
          .select('*')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      
      print('🔍 getUserTerritories: Database response length: ${response.length}');
      if (response.isNotEmpty) {
        print('🔍 getUserTerritories: First territory keys: ${response.first.keys.toList()}');
        print('🔍 getUserTerritories: First territory data: ${response.first}');
        
        // Check for null values in critical fields
        for (int i = 0; i < response.length; i++) {
          final territory = response[i];
          if (territory['area'] == null) {
            print('⚠️ Territory ${territory['id']} has NULL area');
          }
          if (territory['center_lat'] == null) {
            print('⚠️ Territory ${territory['id']} has NULL center_lat');
          }
          if (territory['center_lng'] == null) {
            print('⚠️ Territory ${territory['id']} has NULL center_lng');
          }
        }
      }

      List<Territory> territories = response.map<Territory>((json) {
        // Debug: Log the raw data from database
        print('🔍 getUserTerritories: Raw territory data: ${json.keys.toList()}');
        print('🔍 getUserTerritories: area = ${json['area']}, center_lat = ${json['center_lat']}, center_lng = ${json['center_lng']}');
        print('🔍 getUserTerritories: boundary_points type = ${json['boundary_points']?.runtimeType}');
        
        // The boundary_points are already in the correct format from Supabase
        final territoryJson = Map<String, dynamic>.from(json);
        // Convert created_at to milliseconds since epoch
        territoryJson['created_at'] = DateTime.parse(json['created_at']).millisecondsSinceEpoch;
        
        try {
          return Territory.fromJson(territoryJson);
        } catch (e) {
          print('❌ Error parsing territory ${json['id']}: $e');
          print('❌ Territory data: $territoryJson');
          rethrow;
        }
      }).toList();

      // Enrich with owner colors
      await _enrichTerritoriesWithOwnerColors(territories);
      
      return territories;
    } catch (e) {
      print('❌ Error fetching user territories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTerritoriesIntersectingRun(List<Map<String, dynamic>> runBoundaryPoints) async { return []; }

  Future<List<Map<String, dynamic>>> executeTerritoryConquest(List<Map<String, dynamic>> runBoundaryPoints, String newOwnerId) async { return []; }

  Future<bool> wouldConquerTerritories(List<Map<String, dynamic>> runBoundaryPoints) async { return false; }

  // Debug function removed - function doesn't exist in database schema





  // ==================== NOTIFICATION TRACKING ====================

  /// Mark a steal notification as read by the current user
  Future<bool> markStealNotificationAsRead(String stealId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('mark_steal_notification_read', params: {
        'steal_id': stealId,
        'user_id': user.id,
      });

      print('✅ Marked steal notification as read: $stealId');
      return response as bool;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark a steal notification as deleted by the current user
  Future<bool> markStealNotificationAsDeleted(String stealId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('mark_steal_notification_deleted', params: {
        'steal_id': stealId,
        'user_id': user.id,
      });

      print('✅ Marked steal notification as deleted: $stealId');
      return response as bool;
    } catch (e) {
      print('❌ Error marking notification as deleted: $e');
      return false;
    }
  }

  /// Get unread steal notifications count for current user
  Future<int> getUnreadStealNotificationsCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_unread_steal_notifications_count', params: {
        'user_id': user.id,
      });

      return response as int;
    } catch (e) {
      print('❌ Error getting unread notifications count: $e');
      return 0;
    }
  }

  /// Get active (non-deleted) steal notifications for current user
  Future<List<Map<String, dynamic>>> getActiveStealNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_active_steal_notifications', params: {
        'user_id': user.id,
      });

      return response.map<Map<String, dynamic>>((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      print('❌ Error getting active notifications: $e');
      return [];
    }
  }

  // ==================== CONQUEST STATISTICS ====================

  /// Get user's conquest statistics for bottom sheet
  Future<Map<String, dynamic>> getUserConquestStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_user_conquest_summary', params: {
        'p_user_id': user.id,
      });

      if (response != null && response.isNotEmpty) {
        return {
          'territories_conquered': response[0]['territories_conquered'] ?? 0,
          'territories_lost': response[0]['territories_lost'] ?? 0,
          'total_area_conquered': response[0]['total_area_conquered'] ?? 0.0,
          'total_area_lost': response[0]['total_area_lost'] ?? 0.0,
        };
      }
      
      return {
        'territories_conquered': 0,
        'territories_lost': 0,
        'total_area_conquered': 0.0,
        'total_area_lost': 0.0,
      };
    } catch (e) {
      print('❌ Error getting conquest stats: $e');
      return {
        'territories_conquered': 0,
        'territories_lost': 0,
        'total_area_conquered': 0.0,
        'total_area_lost': 0.0,
      };
    }
  }

  /// Get recent conquest history
  Future<List<Map<String, dynamic>>> getRecentConquestHistory({int limit = 10}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_recent_conquest_history', params: {
        'p_user_id': user.id,
        'p_limit': limit,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('❌ Error getting conquest history: $e');
      return [];
    }
  }

  // ==================== USER PROFILE ====================

  /// Create or update user profile
  Future<void> upsertUserProfile({
    required String displayName,
    String? avatarUrl,
    String? userColor,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final profileData = {
        'id': user.id,
        'email': user.email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'user_color': userColor,
      };

      await _supabase
          .from('user_profiles')
          .upsert(profileData);

      print('✅ User profile updated successfully');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile([String? userId]) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final targetUserId = userId ?? user.id;
      print('🔍 Fetching profile for user: $targetUserId');
      
      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', targetUserId)
          .maybeSingle();

      print('🔍 Profile query response: $response');
      return response;
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      
      // If the error is about the table not existing, try to create the profile
      if (e.toString().contains('relation "user_profiles" does not exist')) {
        print('🔧 user_profiles table does not exist, attempting to create profile...');
        try {
          await _supabase.rpc('create_user_profile_if_not_exists', params: {
            'user_id': _supabase.auth.currentUser!.id,
            'email': _supabase.auth.currentUser!.email ?? 'user@example.com',
            'display_name': 'User ${_supabase.auth.currentUser!.id}',
            'user_color': '#3B82F6', // Default blue color
          });
          print('✅ User profile created successfully');
          
          // Try to fetch the profile again
          final retryResponse = await _supabase
              .from('user_profiles')
              .select('*')
              .eq('id', _supabase.auth.currentUser!.id)
              .maybeSingle();
          
          print('🔍 Retry profile response: $retryResponse');
          return retryResponse;
        } catch (createError) {
          print('❌ Failed to create user profile: $createError');
        }
      }
      
      return null;
    }
  }

  /// Update user's color preference
  Future<void> updateUserColor(String colorHex) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_profiles')
          .update({'user_color': colorHex})
          .eq('id', user.id);

      print('✅ User color updated successfully');
    } catch (e) {
      print('❌ Error updating user color: $e');
      rethrow;
    }
  }

  /// Update all territories owned by the current user with their new color
  Future<void> updateAllTerritoryColors(String colorHex) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🎨 Updating all territory colors for user ${user.id} to $colorHex');

      await _supabase
          .from('territories')
          .update({'owner_color': colorHex})
          .eq('owner_id', user.id);

      print('✅ Updated all territory colors successfully');
    } catch (e) {
      print('❌ Error updating territory colors: $e');
      rethrow;
    }
  }

  /// Update user's display name
  Future<void> updateUserDisplayName(String displayName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_profiles')
          .update({'display_name': displayName})
          .eq('id', user.id);

      print('✅ User display name updated successfully');
    } catch (e) {
      final msg = e.toString();
      print('❌ Error updating user display name: $msg');
      if (msg.contains('user_profiles_display_name_unique_ci') || msg.contains('duplicate key')) {
        throw Exception('username_taken');
      }
      rethrow;
    }
  }

  /// Check if a display name is already taken (case-insensitive)
  Future<bool> isDisplayNameTaken(String name) async {
    try {
  final List<dynamic> response = await _supabase
          .from('user_profiles')
          .select('id')
          .ilike('display_name', name)
          .limit(1);
  return response.isNotEmpty;
    } catch (e) {
      print('⚠️ Error checking display name availability: $e');
      return false; // Fail-open; server will still enforce unique index
    }
  }
  
  /// Update user's coins
  Future<void> updateUserCoins(int coins) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('user_profiles')
          .update({'coins': coins})
          .eq('id', user.id);

      print('✅ User coins updated successfully: $coins');
    } catch (e) {
      print('❌ Error updating user coins: $e');
      rethrow;
    }
  }
  
  /// Award coins for a qualifying run using the database function
  // Removed legacy per-run coin awarding; daily challenge is now server-side cumulative.

  /// Get user display name by user ID
  Future<String?> getUserDisplayName(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();

      return response?['display_name'] as String?;
    } catch (e) {
      print('❌ Error fetching user display name: $e');
      return null;
    }
  }

  /// Ensure user profile exists, create if it doesn't
  Future<void> ensureUserProfileExists() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 Ensuring user profile exists for: ${user.id}');
      
      // Try to create the profile if it doesn't exist
      await _supabase.rpc('create_user_profile_if_not_exists', params: {
        'user_id': user.id,
        'email': user.email ?? 'user@example.com',
        'display_name': user.userMetadata?['full_name'] ?? 'User ${user.id}',
        'user_color': '#3B82F6', // Default blue color
      });
      
      print('✅ User profile ensured successfully');
    } catch (e) {
      print('❌ Error ensuring user profile exists: $e');
      rethrow;
    }
  }

  // ==================== USER STATISTICS ====================

  /// Get user statistics
  Future<Map<String, dynamic>?> getUserStatistics([String? userId]) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final targetUserId = userId ?? user.id;
      
      // Get basic user statistics
      final response = await _supabase
          .from('user_statistics')
          .select('*')
          .eq('user_id', targetUserId)
          .maybeSingle();

      Map<String, dynamic> stats;
      
      if (response != null) {
        stats = Map<String, dynamic>.from(response);
      } else {
        // Create default statistics if none exist
        print('📊 Creating default user statistics for user: $targetUserId');
        stats = await _createDefaultUserStatistics(targetUserId);
      }

      // Get total territories count
      final territoriesResponse = await _supabase
          .from('territories')
          .select('id, area')
          .eq('owner_id', targetUserId);
      
      final totalTerritories = territoriesResponse.length;
      final totalArea = territoriesResponse.fold<double>(0.0, (sum, territory) => 
        sum + (territory['area']?.toDouble() ?? 0.0));
      
      // Get largest territory area - ALWAYS calculate from current territories (most accurate)
      double largestTerritoryArea = 0.0;
      if (territoriesResponse.isNotEmpty) {
        largestTerritoryArea = territoriesResponse
            .map((t) => t['area']?.toDouble() ?? 0.0)
            .reduce((a, b) => a > b ? a : b);
      }

      // Ensure all required fields have default values
      stats['total_territories'] = totalTerritories;
      stats['total_territory_area'] = stats['total_territory_area'] ?? totalArea;
      // CRITICAL FIX: Always use calculated largest area, never stale database value
      stats['largest_territory_area'] = largestTerritoryArea; // Always fresh calculation
      stats['total_distance'] = stats['total_distance'] ?? 0.0;
      // total_runs is managed by Flutter on each run completion, not by territory count
      // stats['total_runs'] = stats['total_runs'] ?? totalTerritories; // REMOVED: Wrong logic
      stats['longest_run_distance'] = stats['longest_run_distance'] ?? 0.0;
      stats['longest_run_duration'] = stats['longest_run_duration'] ?? 0;
      stats['territories_conquered'] = stats['territories_conquered'] ?? 0;
      stats['territories_lost'] = stats['territories_lost'] ?? 0;
      // Note: territories_stolen is redundant with territories_conquered, so we don't display it

      return stats;
    } catch (e) {
      print('❌ Error fetching user statistics: $e');
      return null;
    }
  }

  /// Create default user statistics for a new user
  Future<Map<String, dynamic>> _createDefaultUserStatistics(String userId) async {
    try {
      // Create default statistics record
      final response = await _supabase
          .from('user_statistics')
          .insert({
            'user_id': userId,
            'total_distance': 0.0,
            'total_runs': 0,
            'total_territory_area': 0.0,
            // largest_territory_area is calculated dynamically, not stored
            'longest_run_distance': 0.0,
            'longest_run_duration': 0,
            'territories_conquered': 0,
            'territories_lost': 0,
            // Note: territories_stolen is redundant with territories_conquered
            'last_run_date': null,
          })
          .select()
          .single();

      print('✅ Created default user statistics for user: $userId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('❌ Error creating default user statistics: $e');
      // Return default stats even if database insert fails
      return {
        'user_id': userId,
        'total_distance': 0.0,
        'total_runs': 0,
        'total_territory_area': 0.0,
        // largest_territory_area is calculated dynamically, not stored
        'longest_run_distance': 0.0,
        'longest_run_duration': 0,
        'territories_conquered': 0,
        'territories_lost': 0,
        // Note: territories_stolen is redundant with territories_conquered
        'last_run_date': null,
        'total_territories': 0,
      };
    }
  }

  /// Update user statistics after a run or territory conquest
  Future<bool> updateUserStatistics({
    required String userId,
    double? runDistance,
    int? runDuration,
    double? territoryArea,
    bool? territoryConquered,
    bool? territoryLost,
  }) async {
    try {
      print('📊 Updating user statistics for user: $userId');
      
      // Get current statistics
      final currentStats = await getUserStatistics(userId);
      if (currentStats == null) {
        print('❌ Could not get current statistics for user: $userId');
        return false;
      }

      // Prepare update data
      Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update run-related statistics
      if (runDistance != null && runDistance > 0) {
        final currentTotalDistance = (currentStats['total_distance'] ?? 0.0).toDouble();
        final currentLongestDistance = (currentStats['longest_run_distance'] ?? 0.0).toDouble();
        
        updateData['total_distance'] = currentTotalDistance + runDistance;
        updateData['total_runs'] = (currentStats['total_runs'] ?? 0) + 1;
        
        if (runDistance > currentLongestDistance) {
          updateData['longest_run_distance'] = runDistance;
        }
        
        updateData['last_run_date'] = DateTime.now().toIso8601String();
      }

      // Update duration statistics
      if (runDuration != null && runDuration > 0) {
        final currentLongestDuration = currentStats['longest_run_duration'] ?? 0;
        if (runDuration > currentLongestDuration) {
          updateData['longest_run_duration'] = runDuration;
        }
      }

      // Update territory-related statistics
      if (territoryArea != null && territoryArea > 0) {
        final currentTotalArea = (currentStats['total_territory_area'] ?? 0.0).toDouble();
        
        updateData['total_territory_area'] = currentTotalArea + territoryArea;
        
        // largest_territory_area is now calculated dynamically from current territories
        // No need to update it here as it will be recalculated when stats are fetched
      }

      // Update conquest statistics
      if (territoryConquered == true) {
        updateData['territories_conquered'] = (currentStats['territories_conquered'] ?? 0) + 1;
        // Note: territories_stolen is redundant with territories_conquered, so we don't update it separately
      }

      if (territoryLost == true) {
        updateData['territories_lost'] = (currentStats['territories_lost'] ?? 0) + 1;
      }

      // Update statistics in database
      final response = await _supabase
          .from('user_statistics')
          .update(updateData)
          .eq('user_id', userId);

      if (response.isEmpty) {
        print('❌ No statistics record found to update for user: $userId');
        return false;
      }

      print('✅ User statistics updated successfully for user: $userId');
      return true;
    } catch (e) {
      print('❌ Error updating user statistics: $e');
      return false;
    }
  }

  /// Force recompute user statistics from scratch (useful for fixing corrupted data)
  Future<bool> recomputeUserStatistics(String userId) async {
    try {
      print('🔄 Forcing recomputation of user statistics for user: $userId');
      
      // Call the database function to recompute stats
      await _supabase.rpc('recompute_user_stats', params: {
        'target_user_id': userId,
      });
      
      print('✅ User statistics recomputed successfully for user: $userId');
      return true;
    } catch (e) {
      print('❌ Error recomputing user statistics: $e');
      return false;
    }
  }



  // ==================== DAILY CHALLENGE ====================

  // currentUserId getter already defined below in utility methods; avoid duplication
  String? get dailyChallengeCurrentUserId => _supabase.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchDailyChallengeProgress() async {
    try {
      final rpc = await _supabase.rpc('get_daily_challenge_progress');
      if (rpc is Map<String, dynamic>) {
        print('🛰️ Daily challenge RPC result: $rpc');
        return rpc;
      }
      if (rpc is List && rpc.isNotEmpty && rpc.first is Map<String, dynamic>) {
        final mapped = Map<String, dynamic>.from(rpc.first);
        print('🛰️ Daily challenge RPC list[0]: $mapped');
        return mapped;
      }
    } catch (e) {
      print('⚠️ RPC get_daily_challenge_progress failed: $e');
    }
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final rows = await _supabase
          .from('user_challenge_progress')
          .select('*')
          .eq('user_id', user.id)
          .limit(1);
      print('🛰️ Raw user_challenge_progress rows: $rows');
      if (rows.isNotEmpty) {
        final r = Map<String, dynamic>.from(rows.first);
        String? findKey(List<String> candidates){
          for(final k in candidates){ if(r.containsKey(k) && r[k]!=null) return k; }
          return null; }
        final distKey = findKey(['distance_meters','distance','total_distance','total_distance_today']);
        final durKey = findKey(['duration_minutes','minutes','total_minutes','total_minutes_today']);
        final compKey = findKey(['completed','is_completed','done']);
        final coinsKey = findKey(['coins','current_coins','reward_coins']);
        final normalized = {
          'total_distance_today': (r[distKey] as num?)?.toDouble() ?? 0,
          'total_minutes_today': (r[durKey] as num?)?.toInt() ?? 0,
          'completed': r[compKey] == true,
          'target_distance': 500,
          'target_minutes': 10,
          'coins': (r[coinsKey] as num?)?.toInt() ?? 0,
          'raw_row': r,
        };
        print('🛰️ Normalized user_challenge_progress: $normalized');
        return normalized;
      }
    } catch (e) {
      print('⚠️ Fallback user_challenge_progress fetch failed: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createRunAndMaybeAward({required int durationMinutes, required double distanceMeters}) async {
    try {
      final result = await _supabase.rpc('create_run_and_maybe_award', params: {
        'p_duration_minutes': durationMinutes,
        'p_distance_meters': distanceMeters,
      });
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (e) {
      print('❌ Error calling create_run_and_maybe_award: $e');
      return null;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Test database connection with timeout and retry
  Future<bool> testConnection() async {
    const maxRetries = 3;
    const timeoutDuration = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔍 Testing database connection (attempt $attempt/$maxRetries)...');
        
        await _supabase
            .from('user_profiles')
            .select('id')
            .limit(1)
            .timeout(timeoutDuration);
        
        print('✅ Database connection successful on attempt $attempt');
        return true;
      } catch (e) {
        print('❌ Database connection test failed (attempt $attempt/$maxRetries): $e');
        
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Progressive delay
          continue;
        }
        
        return false;
      }
    }
    return false;
  }
  
  // Removed legacy award_daily_challenge RPC wrapper; replaced by create_run_and_maybe_award.
  
  // Removed client-side conquest count adjustment; server recomputes via recompute_user_stats()
}
