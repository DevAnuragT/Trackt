import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../controllers/map/run_tracker_controller.dart';
import '../services/location_service.dart';
import '../views/run/run_page.dart';
import '../views/map/components/simulation_victory_dialog.dart';

enum SimulationPreset {
  centralParkNYC,
  hydeParkLondon,
  presidioSF,
  localProximity,
}

enum SimulationSpeed {
  turbo,   // ~6 seconds
  demo,    // ~14 seconds
  natural, // ~30 seconds
}

class PresetInfo {
  final SimulationPreset preset;
  final String title;
  final String city;
  final String description;
  final IconData icon;
  final double centerLat;
  final double centerLng;
  final double baseRadiusMeters;

  const PresetInfo({
    required this.preset,
    required this.title,
    required this.city,
    required this.description,
    required this.icon,
    required this.centerLat,
    required this.centerLng,
    required this.baseRadiusMeters,
  });
}

class SimulationResult {
  final String presetTitle;
  final String city;
  final double areaM2;
  final double distanceMeters;
  final Duration duration;
  final String simulatedMonadTx;
  final DateTime completedAt;
  final int coinsEarned;

  SimulationResult({
    required this.presetTitle,
    required this.city,
    required this.areaM2,
    required this.distanceMeters,
    required this.duration,
    required this.simulatedMonadTx,
    required this.completedAt,
    this.coinsEarned = 100,
  });
}

class SimulationService extends GetxService {
  final RxBool isSimulating = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString currentPhase = 'Idle'.obs;
  final Rx<SimulationPreset> selectedPreset = SimulationPreset.centralParkNYC.obs;
  final Rx<SimulationSpeed> selectedSpeed = SimulationSpeed.turbo.obs;
  final Rx<SimulationResult?> lastResult = Rx<SimulationResult?>(null);

  Timer? _simulationTimer;
  List<geo.Position> _currentWaypoints = [];
  int _currentIndex = 0;

  static const List<PresetInfo> presets = [
    PresetInfo(
      preset: SimulationPreset.centralParkNYC,
      title: 'Central Park Great Lawn',
      city: 'New York, USA',
      description: 'Classic 520m perimeter loop around Manhattan’s iconic park',
      icon: Icons.park,
      centerLat: 40.7812,
      centerLng: -73.9665,
      baseRadiusMeters: 85.0,
    ),
    PresetInfo(
      preset: SimulationPreset.hydeParkLondon,
      title: 'Hyde Park Serpentine',
      city: 'London, UK',
      description: 'Scenic 480m waterside loop in the heart of Westminster',
      icon: Icons.waves,
      centerLat: 51.5048,
      centerLng: -0.1650,
      baseRadiusMeters: 80.0,
    ),
    PresetInfo(
      preset: SimulationPreset.presidioSF,
      title: 'The Presidio Coast',
      city: 'San Francisco, USA',
      description: 'High-speed 510m circuit overlooking the Golden Gate bay',
      icon: Icons.location_city,
      centerLat: 37.7989,
      centerLng: -122.4662,
      baseRadiusMeters: 90.0,
    ),
    PresetInfo(
      preset: SimulationPreset.localProximity,
      title: 'Local Proximity Loop',
      city: 'Current Location',
      description: 'Simulates a 400m closed route around your exact GPS fix',
      icon: Icons.my_location,
      centerLat: 0.0,
      centerLng: 0.0,
      baseRadiusMeters: 75.0,
    ),
  ];

  PresetInfo get currentPresetInfo {
    return presets.firstWhere(
      (p) => p.preset == selectedPreset.value,
      orElse: () => presets.first,
    );
  }

  /// Generate realistic organic closed-loop GPS waypoints
  List<geo.Position> generateLoopWaypoints({
    required double centerLat,
    required double centerLng,
    required double baseRadiusMeters,
    int pointCount = 36,
  }) {
    List<geo.Position> waypoints = [];
    final now = DateTime.now();

    for (int i = 0; i <= pointCount; i++) {
      final fraction = i / pointCount;
      final angle = fraction * 2 * math.pi;

      // Realistic organic perturbation (creates organic park shape instead of sterile circle)
      final r = baseRadiusMeters * (1.0 + 0.18 * math.cos(2 * angle) - 0.12 * math.sin(3 * angle));

      final latOffset = (r * math.cos(angle)) / 111320.0;
      final cosLat = math.cos(centerLat * math.pi / 180.0);
      final lngOffset = (r * math.sin(angle)) / (111320.0 * (cosLat.abs() > 0.0001 ? cosLat : 1.0));

      final pointLat = centerLat + latOffset;
      final pointLng = centerLng + lngOffset;

      waypoints.add(geo.Position(
        latitude: pointLat,
        longitude: pointLng,
        timestamp: now.add(Duration(seconds: i * 2)),
        accuracy: 3.5,
        altitude: 12.0,
        heading: (angle * 180 / math.pi) % 360,
        speed: 4.2, // ~15 km/h running pace
        speedAccuracy: 0.5,
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
      ));
    }

    return waypoints;
  }

  /// Launch the Judge Simulation
  Future<void> launchSimulation({
    SimulationPreset? preset,
    SimulationSpeed? speed,
    BuildContext? context,
  }) async {
    if (preset != null) selectedPreset.value = preset;
    if (speed != null) selectedSpeed.value = speed;

    final info = currentPresetInfo;
    double lat = info.centerLat;
    double lng = info.centerLng;
    double radius = info.baseRadiusMeters;

    // Handle local GPS fallback
    if (info.preset == SimulationPreset.localProximity) {
      final locService = Get.find<LocationService>();
      final cur = locService.currentPosition.value;
      if (cur != null) {
        lat = cur.latitude;
        lng = cur.longitude;
      } else {
        // Fallback to Central Park if no GPS available
        lat = 40.7812;
        lng = -73.9665;
      }
    }

    print('🧪 Generating simulation waypoints around ($lat, $lng)...');
    _currentWaypoints = generateLoopWaypoints(
      centerLat: lat,
      centerLng: lng,
      baseRadiusMeters: radius,
      pointCount: 36,
    );

    if (_currentWaypoints.isEmpty) return;

    // Navigate to RunPage if not already there
    if (Get.currentRoute != '/run' && !(Get.isDialogOpen ?? false)) {
      Get.to(() => const RunPageAutoStart(autoStart: false));
      // Brief pause to allow Mapbox to initialize
      await Future.delayed(const Duration(milliseconds: 600));
    }

    final runController = Get.find<RunTrackerController>();

    // Start the simulated run on the controller
    await runController.startSimulatedRun(initialPosition: _currentWaypoints.first);

    isSimulating.value = true;
    progress.value = 0.0;
    currentPhase.value = 'Running Loop';
    _currentIndex = 0;

    // Configure tick rate according to selected speed
    int intervalMs = 150; // Turbo default (~5.4s)
    switch (selectedSpeed.value) {
      case SimulationSpeed.turbo:
        intervalMs = 140; // ~5 sec total
        break;
      case SimulationSpeed.demo:
        intervalMs = 380; // ~14 sec total
        break;
      case SimulationSpeed.natural:
        intervalMs = 800; // ~29 sec total
        break;
    }

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) async {
      if (!isSimulating.value || !runController.isRunning.value) {
        timer.cancel();
        return;
      }

      if (_currentIndex < _currentWaypoints.length) {
        final point = _currentWaypoints[_currentIndex];
        final currentFraction = _currentIndex / (_currentWaypoints.length - 1);
        progress.value = currentFraction;

        if (currentFraction > 0.75) {
          currentPhase.value = 'Loop Closing Detected';
        } else {
          currentPhase.value = 'Pacing (${(_currentIndex + 1)}/${_currentWaypoints.length})';
        }

        runController.injectSimulatedPosition(point, progress: currentFraction);
        _currentIndex++;
      } else {
        // Simulation path completed! Complete run
        timer.cancel();
        currentPhase.value = 'Finalizing Conquest...';
        await _completeSimulation(runController, info);
      }
    });
  }

  Future<void> _completeSimulation(RunTrackerController runController, PresetInfo info) async {
    try {
      final double area = runController.totalDistance.value > 0
          ? (runController.totalDistance.value * runController.totalDistance.value) / 12.56
          : 16850.0;

      final Duration dur = runController.runDuration.value;
      final double dist = runController.totalDistance.value;

      // End the run in the tracker
      await runController.endSimulatedRun();

      // Generate simulated Monad transaction hash for demonstration
      final hex = math.Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final simulatedTx = '0x143a9b${hex}7c8d9e2f4a10bc39e143';

      final result = SimulationResult(
        presetTitle: info.title,
        city: info.city,
        areaM2: area,
        distanceMeters: dist > 0 ? dist : 520.0,
        duration: dur.inSeconds > 0 ? dur : const Duration(minutes: 3, seconds: 45),
        simulatedMonadTx: simulatedTx,
        completedAt: DateTime.now(),
        coinsEarned: 100,
      );

      lastResult.value = result;
      isSimulating.value = false;
      currentPhase.value = 'Conquest Completed!';

      // Pop up the Victory Dialog for the evaluator
      Future.delayed(const Duration(milliseconds: 350), () {
        if (Get.context != null) {
          Get.dialog(
            SimulationVictoryDialog(result: result),
            barrierDismissible: true,
          );
        }
      });
    } catch (e) {
      print('❌ Error completing simulation: $e');
      isSimulating.value = false;
    }
  }

  /// Cancel any active simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    isSimulating.value = false;
    progress.value = 0.0;
    currentPhase.value = 'Cancelled';

    if (Get.isRegistered<RunTrackerController>()) {
      Get.find<RunTrackerController>().cancelSimulatedRun();
    }
  }

  @override
  void onClose() {
    _simulationTimer?.cancel();
    super.onClose();
  }
}
