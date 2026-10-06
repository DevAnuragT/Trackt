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
      backgroundColor: const Color(0xFF2D2D2D),
      buttonColor: Colors.green,
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
        // Pause button with circular design
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => controller.pauseRun(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Pause',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Stop button with circular design
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red[600],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _showStopConfirmation(controller),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPausedControls(RunTrackerController controller) {
    return Row(
      children: [
        // Resume button with green solid color
        Expanded(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => controller.resumeRun(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Resume',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Stop button
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red[600],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _showStopConfirmation(controller),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue[500],
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Uploading Territory...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ) : const SizedBox.shrink()),
      ],
    );
  }

  void _showStopConfirmation(RunTrackerController controller) {
    showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Stop Run', style: TextStyle(color: Colors.white)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
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
