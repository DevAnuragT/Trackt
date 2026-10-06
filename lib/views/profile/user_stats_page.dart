import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/database_service.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({super.key});

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  final DatabaseService _databaseService = Get.find<DatabaseService>();
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final stats = await _databaseService.getUserStatistics();
      if (stats != null) {
        setState(() {
          _userStats = stats;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load user statistics';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading user statistics: $e';
        _isLoading = false;
      });
    }
  }

  /// Force recompute user statistics from database
  // Future<void> _recomputeStatistics() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //       _error = null;
  //     });

  //     // Statistics recomputation started - loading state will show in UI

  //     // Force recompute statistics
  //     final success = await _databaseService.recomputeUserStatistics(
  //       _databaseService.currentUserId ?? '',
  //     );

  //     if (success) {
  //       // Reload statistics after recomputation
  //       await _loadUserStats();
        
  //       // Statistics updated successfully - UI will reflect the changes
  //     } else {
  //       setState(() {
  //         _error = 'Failed to recompute statistics';
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = 'Error recomputing statistics: $e';
  //       _isLoading = false;
  //     });
  //   }
  // }



  String _formatDistance(double? distance) {
    if (distance == null || distance <= 0) return '0 m';
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${remainingSeconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  String _formatArea(double? area) {
    if (area == null || area <= 0) return '0 km²';
    return '${(area / 1000000).toStringAsFixed(2)} km²';
  }

  /// Get safe integer value with default fallback
  int _getSafeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  /// Get safe double value with default fallback
  double _getSafeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[700]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF2D2D2D),
  //       borderRadius: BorderRadius.circular(6),
  //       border: Border.all(color: Colors.grey[700]!, width: 0.5),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  //       child: Row(
  //         children: [
  //           Icon(
  //             icon,
  //             size: 20,
  //             color: color,
  //           ),
  //           const SizedBox(width: 6),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: const TextStyle(
  //                     color: Colors.grey,
  //                     fontSize: 11,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 1),
  //                 Text(
  //                   value,
  //                   style: const TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 15,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text(
          'User Statistics',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserStats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserStats,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'Your Running & Territory Stats',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track your progress and achievements',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Running Stats Section
                        const Text(
                          'Running Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                          childAspectRatio: 2,
                          children: [
                            _buildStatCard(
                              'Total Runs',
                              '${_getSafeInt(_userStats?['total_runs'])}',
                              Icons.directions_run,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Total Distance',
                              _formatDistance(_getSafeDouble(_userStats?['total_distance'])),
                              Icons.straighten,
                              Colors.green,
                            ),
                            _buildStatCard(
                              'Longest Run',
                              _formatDistance(_getSafeDouble(_userStats?['longest_run_distance'])),
                              Icons.trending_up,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'Longest Duration',
                              _formatDuration(_getSafeInt(_userStats?['longest_run_duration'])),
                              Icons.timer,
                              Colors.purple,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Territory Stats Section
                        const Text(
                          'Territory Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                          childAspectRatio: 2,
                          children: [
                            _buildStatCard(
                              'Total Territories',
                              '${_getSafeInt(_userStats?['total_territories'])}',
                              Icons.map,
                              Colors.indigo,
                            ),
                            _buildStatCard(
                              'Total Area',
                              _formatArea(_getSafeDouble(_userStats?['total_territory_area'])),
                              Icons.area_chart,
                              Colors.teal,
                            ),
                            _buildStatCard(
                              'Largest Territory',
                              _formatArea(_getSafeDouble(_userStats?['largest_territory_area'])),
                              Icons.expand,
                              Colors.amber,
                            ),
                            _buildStatCard(
                              'Territories Conquered',
                              '${_getSafeInt(_userStats?['territories_conquered'])}',
                              Icons.flag,
                              Colors.red,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Conquest Stats Section
                        const Text(
                          'Conquest Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                          childAspectRatio: 2,
                          children: [
                            _buildStatCard(
                              'Territories Lost',
                              '${_getSafeInt(_userStats?['territories_lost'])}',
                              Icons.remove_circle,
                              Colors.red[300]!,
                            ),
                            _buildStatCard(
                              'Success Rate',
                              _calculateSuccessRate(),
                              Icons.trending_up,
                              Colors.green,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Last Run Info
                        if (_userStats?['last_run_date'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2D2D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[700]!, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.blue[300],
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Last Run',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _formatLastRunDate(_userStats!['last_run_date']),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
        ),
      );
  }

  String _formatLastRunDate(dynamic lastRunDate) {
    try {
      if (lastRunDate is String) {
        final date = DateTime.parse(lastRunDate);
        final now = DateTime.now();
        final difference = now.difference(date);
        
        if (difference.inDays > 0) {
          return '${difference.inDays} days ago';
        } else if (difference.inHours > 0) {
          return '${difference.inHours} hours ago';
        } else if (difference.inMinutes > 0) {
          return '${difference.inMinutes} minutes ago';
        } else {
          return 'Just now';
        }
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _calculateSuccessRate() {
    final territoriesConquered = _getSafeInt(_userStats?['territories_conquered'] ?? 0);
    final territoriesLost = _getSafeInt(_userStats?['territories_lost'] ?? 0);

    // If no conquests or losses, show 100% success
    if (territoriesConquered == 0 && territoriesLost == 0) {
      return '100%';
    }

    // If only losses, show 0% success
    if (territoriesConquered == 0 && territoriesLost > 0) {
      return '0%';
    }

    // If only conquests, show 100% success
    if (territoriesConquered > 0 && territoriesLost == 0) {
      return '100%';
    }

    // Calculate success rate: conquered / (conquered + lost) * 100
    final totalBattles = territoriesConquered + territoriesLost;
    final successRate = (territoriesConquered / totalBattles) * 100;
    
    return '${successRate.toStringAsFixed(0)}%';
  }
}
