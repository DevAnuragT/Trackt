import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trackt/services/run_history_service.dart';
import 'package:trackt/models/territory/territory_model.dart';

class TerritoryHistoryPage extends StatelessWidget {
  const TerritoryHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TerritoryHistoryService territoryHistoryService = Get.find<TerritoryHistoryService>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Territory History'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // Removed delete button - territories are stored in cloud and cannot be deleted locally
      ),
      backgroundColor: Colors.black,
      body: Obx(() {
        final allTerritories = territoryHistoryService.getAllTerritories();
        
        if (allTerritories.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No territories yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Start running to claim territories',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          children: [
            // Statistics Summary
            _buildStatsHeader(territoryHistoryService),
            
            // Territory List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allTerritories.length,
                itemBuilder: (context, index) {
                  final territory = allTerritories[index];
                  return _buildTerritoryCard(territory, index);
                },
              ),
            ),
          ],
        );
      }),
    );
  }
  
  Widget _buildStatsHeader(TerritoryHistoryService service) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Obx(() {
        final stats = service.getTerritoryStats();
        return Column(
          children: [
            const Text(
              'Territory Statistics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Territories',
                  '${stats['totalTerritories']}',
                  Icons.map,
                ),
                _buildStatItem(
                  'Total Area',
                  '${(stats['totalArea'] / 1000000).toStringAsFixed(2)} km²',
                  Icons.area_chart,
                ),
                _buildStatItem(
                  'Avg Area',
                  '${(stats['averageArea'] / 1000000).toStringAsFixed(2)} km²',
                  Icons.analytics,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTerritoryCard(Territory territory, int index) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[700]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Territory #${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(territory.createdAt),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRunStat(
                    'Area',
                    '${(territory.area / 1000000).toStringAsFixed(2)} km²',
                    Icons.area_chart,
                  ),
                ),
                Expanded(
                  child: _buildRunStat(
                    'Center',
                    '${territory.center.latitude.toStringAsFixed(4)}, ${territory.center.longitude.toStringAsFixed(4)}',
                    Icons.location_on,
                  ),
                ),
                Expanded(
                  child: _buildRunStat(
                    'Points',
                    '${territory.boundaryPoints.length}',
                    Icons.polyline,
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
  
  Widget _buildRunStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  // String _formatDuration(Duration duration) {
  //   String twoDigits(int n) => n.toString().padLeft(2, '0');
  //   String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  //   String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
  //   if (duration.inHours > 0) {
  //     return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  //   } else {
  //     return "$twoDigitMinutes:$twoDigitSeconds";
  //   }
  // }
  
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
