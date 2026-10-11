import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/map/run_tracker_controller.dart';

class RunStatsWidget extends StatelessWidget {
  const RunStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final runController = Get.find<RunTrackerController>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1733).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8338EC).withOpacity(0.3), width: 1),
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Distance',
            '${(runController.totalDistance.value / 1000).toStringAsFixed(2)} km', // Convert meters to km
            Icons.straighten,
            const Color(0xFF00F5D4),
          ),
          _buildStatItem(
            'Duration',
            _formatDuration(runController.runDuration.value),
            Icons.timer,
            const Color(0xFFFFBE0B),
          ),
          _buildStatItem(
            'Speed',
            '${_calculateSpeed(runController.totalDistance.value / 1000, runController.runDuration.value).toStringAsFixed(1)} km/h', // Use km for calculation
            Icons.speed,
            const Color(0xFF8338EC),
          ),
        ],
      )),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  double _calculateSpeed(double distanceKm, Duration duration) {
    if (duration.inSeconds == 0) return 0.0;
    return distanceKm / (duration.inSeconds / 3600);
  }
}
