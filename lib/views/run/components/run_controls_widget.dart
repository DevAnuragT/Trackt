import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trackt/views/run/components/start_run_button.dart';
import '../../../controllers/map/run_tracker_controller.dart';
import '../../../core/enums/run_state.dart';
import '../../../services/location_service.dart';

class RunControlsWidget extends StatelessWidget {
  final bool autoStart;
  const RunControlsWidget({super.key, this.autoStart = false});

  @override
  Widget build(BuildContext context) {
    final runController = Get.find<RunTrackerController>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        switch (runController.runState.value) {
          case RunState.idle:
            return _buildStartButton(runController);
          case RunState.running:
            return _buildRunningControls(runController);
          case RunState.paused:
            return _buildPausedControls(runController);
          case RunState.finished:
            return _buildFinishedControls(runController);
        }
      }),
    );
  }

  Widget _buildStartButton(RunTrackerController controller) {
    return Obx(() => CountdownStartButton(
      onPressed: controller.isStartingRun.value ? null : () => controller.startRun(),
      backgroundColor: const Color(0xFF6366F1),
      buttonColor: const Color(0xFF6366F1),
      textColor: Colors.white,
      isLoading: controller.isStartingRun.value,
      autoStart: autoStart,
      onCountdownStart: () async {
        // Lightweight pre-initialization: ensure permissions and get a quick position fix
        try {
          // This avoids showing dialogs here; the bottom sheet flow already handled first-time prompts
          await Get.find<LocationService>().requestLocationPermission();
          // Try to get a quick high-accuracy fix so GPS warms up during countdown
          await Get.find<LocationService>().getHighAccuracyLocation();
        } catch (_) {}
      },
    ));
  }

  Widget _buildRunningControls(RunTrackerController controller) {
    return Row(
      children: [
        Expanded(
          child: _controlButton(
            label: 'Pause',
            icon: Icons.pause_rounded,
            onTap: () => controller.pauseRun(),
            filled: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _controlButton(
            label: 'Stop',
            icon: Icons.stop_rounded,
            onTap: () => _showStopConfirmation(controller),
            color: const Color(0xFFEF4444),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPausedControls(RunTrackerController controller) {
    return Row(
      children: [
        Expanded(
          child: _controlButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            onTap: () => controller.resumeRun(),
            color: const Color(0xFF6366F1),
            filled: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _controlButton(
            label: 'Stop',
            icon: Icons.stop_rounded,
            onTap: () => _showStopConfirmation(controller),
            color: const Color(0xFFEF4444),
            filled: true,
          ),
        ),
      ],
    );
  }

  /// Flat, consistent run-control button matching the app's design system.
  Widget _controlButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFF6366F1),
    bool filled = true,
  }) {
    final fg = filled ? Colors.white : const Color(0xFFFAFAFA);
    return Material(
      color: filled ? color : const Color(0xFF202024),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: const Color(0xFF2A2A2F)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedControls(RunTrackerController controller) {
    return Column(
      children: [
        // Run completed successfully message - COMMENTED OUT
        /*
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Run Completed & Saved!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        */
        // Territory Upload Status Display
        Obx(() => controller.isUploadingTerritory.value ? Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF202024),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2F)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Uploading territory…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ) : const SizedBox.shrink()),
      ],
    );
  }

  void _showStopConfirmation(RunTrackerController controller) {
    showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF17171A),
        title: const Text('Stop run?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to stop this run?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        controller.stopRun();
      }
    });
  }
}
