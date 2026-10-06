import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/map/run_tracker_controller.dart';

import '../../../services/run_history_service.dart'; // Added import for TerritoryHistoryService
import '../../../services/database_service.dart'; // Added import for DatabaseService
import '../../../controllers/map/territory_display_controller.dart'; // Added for flyToTerritory
import '../../../models/territory/territory_model.dart'; // Added for Territory class
import '../../run/run_page.dart';
import '../../../services/location_permission_service.dart';
import '../../../widgets/shimmer_skeleton.dart';

/// Controller for managing bottom sheet data and statistics
class BottomSheetController extends GetxController {
  final RxInt totalRuns = 0.obs;
  final RxBool isLoadingStats = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadUserStatistics();
  }
  
  /// Load user statistics from cloud database
  Future<void> loadUserStatistics() async {
    try {
      isLoadingStats.value = true;
      
      final databaseService = Get.find<DatabaseService>();
      
      // Get user statistics including total runs
      final stats = await databaseService.getUserStatistics();
      if (stats != null) {
        totalRuns.value = stats['total_runs'] ?? 0;
        print('✅ Loaded user statistics: ${totalRuns.value} total runs');
      }
    } catch (e) {
      print('❌ Error loading user statistics: $e');
    } finally {
      isLoadingStats.value = false;
    }
  }
  
  /// Refresh statistics (called when returning from run page)
  Future<void> refreshStatistics() async {
    await loadUserStatistics();
  }
  
  /// Force refresh statistics from server (for conquest updates)
  Future<void> forceRefreshStatistics() async {
    try {
      isLoadingStats.value = true;
      
      final databaseService = Get.find<DatabaseService>();
      final user = databaseService.currentUserId;
      
      if (user != null) {
        // Force server-side recomputation
        await databaseService.recomputeUserStatistics(user);
        // Then load the updated statistics
        await loadUserStatistics();
        print('✅ Statistics force refreshed from server');
      }
    } catch (e) {
      print('❌ Error force refreshing statistics: $e');
    } finally {
      isLoadingStats.value = false;
    }
  }
  

}

class TerritoryBottomSheet extends StatelessWidget {
  const TerritoryBottomSheet({super.key});

  /// Force refresh the bottom sheet data
  static void refresh() {
    // Trigger a rebuild by updating the territory history service
    try {
      final historyService = Get.find<TerritoryHistoryService>();
      historyService.recentTerritories.refresh();
      
      // Also refresh statistics if controller exists
      if (Get.isRegistered<BottomSheetController>()) {
        final bottomSheetController = Get.find<BottomSheetController>();
        bottomSheetController.refreshStatistics();
      }
      
      print('✅ Bottom sheet refreshed with cloud data');
    } catch (e) {
      print('⚠️ Could not refresh bottom sheet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BottomSheetController>(
      init: BottomSheetController(),
      builder: (controller) {
        return DraggableScrollableSheet(
          initialChildSize: 0.26,  // Start at 22% of screen height
          minChildSize: 0.10,      // Minimum 10% when collapsed
          maxChildSize: 0.75,      // Maximum 75% when expanded
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), // Dark background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 15,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600], // Darker drag handle
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          const Text(
                            'My Territories',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // White text for dark mode
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Territory stats
                          _buildTerritoryStats(controller),
                          
                          const SizedBox(height: 20),
                          
                          // Start Run button
                          _buildStartRunButton(),
                          
                          const SizedBox(height: 20),
                          
                          // Run history
                          _buildRunHistory(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTerritoryStats(BottomSheetController controller) {
    return Obx(() {
      try {
        final historyService = Get.find<TerritoryHistoryService>();
        final allTerritories = historyService.allTerritories;
        // Calculate total territory area from Supabase data (area is m²)
        double totalArea = allTerritories.fold(0.0, (sum, territory) => sum + territory.area);
        String areaText = '${(totalArea / 1000000).toStringAsFixed(2)} km²';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D), // Dark card background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 0.5), // Subtle border
          ),
          child: Column(
            children: [
              // First row: Total Territory and Total Runs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  controller.isLoadingStats.value
                      ? ShimmerSkeleton(height: 40, width: 120, borderRadius: BorderRadius.circular(8))
                      : _buildStatItem('Total Territory', areaText, ''),
                  controller.isLoadingStats.value
                      ? ShimmerSkeleton(height: 40, width: 120, borderRadius: BorderRadius.circular(8))
                      : _buildStatItem('Total Runs', '${controller.totalRuns.value}', ''),
                ],
              ),
            ],
          ),
        );
      } catch (e) {
        // Fallback to default values if service not available
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Territory', '0', 'km²'),
                  _buildStatItem('Territories Conquered', '0', ''),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem('Territories Lost', '0', ''),
                ],
              ),
            ],
          ),
        );
      }
    });
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue, // Keep blue accent for values
          ),
        ),
        if (unit.isNotEmpty) ...[
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey, // Keep grey for units
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70, // Light text for dark mode
          ),
        ),
      ],
    );
  }

  Widget _buildStartRunButton() {
    // Safe controller access
    try {
      final runTracker = Get.find<RunTrackerController>();
      
      return Obx(() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: runTracker.isRunning.value 
              ? null  // Disable if already running
              : () async {
                  // Show "Allow all the time" dialog (first time) then open settings
                  try {
                    final perms = Get.find<LocationPermissionService>();
                    await perms.maybeShowAllowAllTimeDialogAndOpenSettings();
                  } catch (_) {}
                  // Navigate directly to RunPage; it will auto-start countdown
                  _showRunPage(autoStart: true);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: runTracker.isRunning.value 
                ? Colors.grey 
                : Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            runTracker.isRunning.value 
                ? 'Run in Progress...' 
                : 'Start Run',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ));
    } catch (e) {
      // Fallback if controller not found
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _showRunPage(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Start Run',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  void _showRunPage({bool autoStart = false}) {
    Get.to(() => RunPageAutoStart(autoStart: autoStart));
  }
  
  /// Fly to a specific territory on the map
  void _flyToTerritory(Territory territory) {
    try {
      // Find the TerritoryDisplayController to fly to the territory
      if (Get.isRegistered<TerritoryDisplayController>()) {
        final territoryController = Get.find<TerritoryDisplayController>();
        territoryController.flyToTerritory(territory);
        
        // Close the bottom sheet to show the map using Get.back() instead of Navigator
        Get.back();
        
        print('🗺️ Flying to territory: ${territory.id}');
      } else {
        print('❌ TerritoryDisplayController not found');
        // Handle gracefully - show loading state or disable button
        return;
      }
    } catch (e) {
      print('❌ Error flying to territory: $e');
      // Handle gracefully - could show a subtle indicator or retry option
    }
  }

  Widget _buildRunHistory() {
    final historyService = Get.find<TerritoryHistoryService>();
    return Obx(() {
      final recentTerritories = historyService.recentTerritories;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Territories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Showing ${recentTerritories.length} of ${historyService.allTerritories.length} total territories',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          if (recentTerritories.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[600]!, width: 0.5),
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF2D2D2D),
              ),
              child: const Center(
                child: Text(
                  'No territories yet. Start your first run to claim territory!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTerritories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final territory = recentTerritories[index];
                return GestureDetector(
                  onTap: () => _flyToTerritory(territory),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[600]!, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF2D2D2D),
                    ),
                    child: Row(
                      children: [
                        // Territory icon with status color
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getTerritoryStatusColor(territory).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getTerritoryStatusIcon(territory),
                            color: _getTerritoryStatusColor(territory),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Territory details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(territory.area / 1000000).toStringAsFixed(2)} km²',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getTerritoryStatusText(territory),
                                style: TextStyle(
                                  color: _getTerritoryStatusColor(territory).withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Date
                        Text(
                          _formatDate(territory.createdAt),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 100), // Extra space for scrolling
        ],
      );
    });
  }

  // String _formatDuration(int durationSeconds) {
  //   final minutes = durationSeconds ~/ 60;
  //   final seconds = durationSeconds % 60;
  //   return '${minutes}m ${seconds}s';
  // }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  /// Get territory status color based on ownership and conquest status
  Color _getTerritoryStatusColor(Territory territory) {
    try {
      final databaseService = Get.find<DatabaseService>();
      final currentUserId = databaseService.currentUserId;
      
      if (currentUserId == null) return Colors.grey;
      
      // Check if this territory is still owned by current user
      if (territory.ownerId == currentUserId) {
        return Colors.green; // Still owned - green
      } else {
        // Territory was lost - check if it was partially or completely stolen
        // We'll use different colors for different loss types
        final lossType = _getTerritoryLossType(territory);
        switch (lossType) {
          case 'complete':
            return Colors.red; // Completely lost - red
          case 'partial':
            return Colors.orange; // Partially lost - orange
          default:
            return Colors.red; // Default to red for lost
        }
      }
    } catch (e) {
      // Fallback to green if we can't determine status
      return Colors.green;
    }
  }

  /// Get territory status icon based on ownership and conquest status
  IconData _getTerritoryStatusIcon(Territory territory) {
    try {
      final databaseService = Get.find<DatabaseService>();
      final currentUserId = databaseService.currentUserId;
      
      if (currentUserId == null) return Icons.place;
      
      // Check if this territory is still owned by current user
      if (territory.ownerId == currentUserId) {
        return Icons.place; // Still owned - place icon
      } else {
        // Territory was lost - use different icons for different loss types
        final lossType = _getTerritoryLossType(territory);
        switch (lossType) {
          case 'complete':
            return Icons.remove_circle_outline; // Completely lost - remove circle
          case 'partial':
            return Icons.remove_circle; // Partially lost - filled remove circle
          default:
            return Icons.remove_circle_outline; // Default to remove circle
        }
      }
    } catch (e) {
      // Fallback to place icon if we can't determine status
      return Icons.place;
    }
  }

  /// Get territory status text for display
  String _getTerritoryStatusText(Territory territory) {
    try {
      final databaseService = Get.find<DatabaseService>();
      final currentUserId = databaseService.currentUserId;
      
      if (currentUserId == null) return 'Territory claimed';
      
      // Check if this territory is still owned by current user
      if (territory.ownerId == currentUserId) {
        return 'Territory claimed'; // Still owned
      } else {
        // Check if this was a partial conquest (territory still exists but reduced)
        final lossType = _getTerritoryLossType(territory);
        switch (lossType) {
          case 'complete':
            return 'Territory lost'; // Completely lost
          case 'partial':
            return 'Territory partially lost'; // Partially lost
          default:
            return 'Territory lost'; // Default to lost
        }
      }
    } catch (e) {
      // Fallback text if we can't determine status
      return 'Territory claimed';
    }
  }

  /// Get territory status with enhanced conquest detection
  /// Returns: 'owned', 'lost', or 'partial'
  // String _getTerritoryStatus(Territory territory) {
  //   try {
  //     final databaseService = Get.find<DatabaseService>();
  //     final currentUserId = databaseService.currentUserId;
      
  //     if (currentUserId == null) return 'owned';
      
  //     // Check if this territory is still owned by current user
  //     if (territory.ownerId == currentUserId) {
  //       return 'owned'; // Still owned
  //     } else {
  //       // Territory was lost - check if it was partial or complete conquest
  //       return _getTerritoryLossType(territory);
  //     }
  //   } catch (e) {
  //     // Fallback to owned if we can't determine status
  //     return 'owned';
  //   }
  // }

  /// Determine if a territory was completely or partially lost by checking territory_steals table
  /// Returns: 'complete', 'partial', or 'lost' (default)
  String _getTerritoryLossType(Territory territory) {
    try {
      final databaseService = Get.find<DatabaseService>();
      final currentUserId = databaseService.currentUserId;
      
      if (currentUserId == null) return 'lost';
      
      // This territory is currently owned by someone else, but we need to check
      // if the current user was the previous owner and if it was a partial conquest
      
      // TODO: In the future, we could implement a more sophisticated check by:
      // 1. Looking up the territory_steals table for this territory
      // 2. Checking if the current user was the previous owner
      // 3. Checking the reason field ('complete_conquest' vs 'partial_conquest')
      // 4. Checking the overlap_percentage to determine if it was truly partial
      
      // For now, we'll use a heuristic based on territory area
      // If the territory area is very small, it might be a remnant from partial conquest
      if (territory.area < 100) { // Less than 100 m² - likely a remnant
        return 'partial';
      } else {
        return 'complete'; // Larger territory - likely complete conquest
      }
      
    } catch (e) {
      // Fallback to complete loss if we can't determine
      return 'complete';
    }
  }
  
  // /// Build conquest history section
  // Widget _buildConquestHistory(BottomSheetController controller) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF2D2D2D), // Dark card background
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: Colors.grey[700]!, width: 0.5), // Subtle border
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Section title
  //         const Text(
  //           'Recent Conquests',
  //           style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(height: 12),
          
  //         // Conquest history list
  //         FutureBuilder<List<Map<String, dynamic>>>(
  //           future: Get.find<DatabaseService>().getRecentConquestHistory(limit: 5),
  //           builder: (context, snapshot) {
  //             if (snapshot.connectionState == ConnectionState.waiting) {
  //               return const Center(
  //                 child: CircularProgressIndicator(
  //                   color: Colors.blue,
  //                   strokeWidth: 2,
  //                 ),
  //               );
  //             }
              
  //             if (snapshot.hasError) {
  //               return const Text(
  //                 'Error loading conquest history',
  //                 style: TextStyle(color: Colors.red),
  //               );
  //             }
              
  //             final conquests = snapshot.data ?? [];
              
  //             if (conquests.isEmpty) {
  //               return const Text(
  //                 'No conquests yet',
  //                 style: TextStyle(
  //                   color: Colors.grey,
  //                   fontStyle: FontStyle.italic,
  //                 ),
  //               );
  //             }
              
  //             return Column(
  //               children: conquests.map((conquest) {
  //                 final area = conquest['territory_area'] ?? 0.0;
  //                 final areaText = area >= 10000
  //                     ? '${(area / 10000).toStringAsFixed(2)} ha'
  //                     : '${area.toStringAsFixed(0)} m²';
                  
  //                 return Container(
  //                   margin: const EdgeInsets.only(bottom: 8),
  //                   padding: const EdgeInsets.all(8),
  //                   decoration: BoxDecoration(
  //                     color: const Color(0xFF3D3D3D),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(
  //                         Icons.flag,
  //                         color: Colors.green,
  //                         size: 16,
  //                       ),
  //                       const SizedBox(width: 8),
  //                       Expanded(
  //                         child: Text(
  //                           'Conquered $areaText',
  //                           style: const TextStyle(
  //                             color: Colors.white,
  //                             fontSize: 14,
  //                           ),
  //                         ),
  //                       ),
  //                       Text(
  //                         _formatDate(DateTime.parse(conquest['created_at'])),
  //                         style: const TextStyle(
  //                           color: Colors.grey,
  //                           fontSize: 12,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               }).toList(),
  //             );
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }
  

}
