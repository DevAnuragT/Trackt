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
          // Zoom In button
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton(
              mini: true,
              heroTag: "zoom_in_btn", // Unique hero tag
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: mapController.zoomIn,
              child: const Icon(Icons.add),
            ),
          ),
          
          // Zoom Out button
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            child: FloatingActionButton(
              mini: true,
              heroTag: "zoom_out_btn", // Unique hero tag
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              onPressed: mapController.zoomOut,
              child: const Icon(Icons.remove),
            ),
          ),
          
          // Recenter to user location button
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            child: FloatingActionButton(
              mini: true,
              heroTag: "recenter_btn", // Unique hero tag
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              onPressed: mapController.moveToUserLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          
          // Removed map refresh button as per requirements
        ],
      ),
    );
  }
}
