import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/map/map_controller.dart';

class MapControlsWidget extends StatelessWidget {
  const MapControlsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final mapController = Get.find<MapController>();

    return Container(
      margin: const EdgeInsets.only(bottom: 80), // Shift controls upward
      child: Column(
        children: [
          _controlButton(
            tag: 'zoom_in_btn',
            icon: Icons.add,
            onPressed: mapController.zoomIn,
          ),
          const SizedBox(height: 8),
          _controlButton(
            tag: 'zoom_out_btn',
            icon: Icons.remove,
            onPressed: mapController.zoomOut,
          ),
          const SizedBox(height: 8),
          _controlButton(
            tag: 'recenter_btn',
            icon: Icons.my_location,
            onPressed: mapController.moveToUserLocation,
            accent: true,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required String tag,
    required IconData icon,
    required VoidCallback onPressed,
    bool accent = false,
  }) {
    return FloatingActionButton(
      mini: true,
      heroTag: tag,
      elevation: 0,
      backgroundColor: const Color(0xFF17171A).withValues(alpha: 0.92),
      foregroundColor: accent ? const Color(0xFF6366F1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: (accent ? const Color(0xFF6366F1) : Colors.white)
              .withValues(alpha: 0.25),
        ),
      ),
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }
}
