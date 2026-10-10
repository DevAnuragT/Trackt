import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trackt/services/simulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimulationService service;

  setUp(() {
    Get.reset();
    service = SimulationService();
  });

  tearDown(() {
    service.stopSimulation();
    Get.reset();
  });

  group('SimulationService - Presets & Configuration', () {
    test('defines 4 evaluation presets with valid coordinates', () {
      expect(SimulationService.presets.length, equals(4));

      for (final preset in SimulationService.presets) {
        expect(preset.title, isNotEmpty);
        expect(preset.city, isNotEmpty);
        expect(preset.description, isNotEmpty);
        expect(preset.baseRadiusMeters, greaterThan(50.0));

        if (preset.preset != SimulationPreset.localProximity) {
          expect(preset.centerLat, isNot(0.0));
          expect(preset.centerLng, isNot(0.0));
          expect(preset.centerLat, inInclusiveRange(-90.0, 90.0));
          expect(preset.centerLng, inInclusiveRange(-180.0, 180.0));
        }
      }
    });

    test('default preset is Central Park NYC with turbo speed', () {
      expect(service.selectedPreset.value, equals(SimulationPreset.centralParkNYC));
      expect(service.selectedSpeed.value, equals(SimulationSpeed.turbo));
      expect(service.currentPresetInfo.city, equals('New York, USA'));
      expect(service.isSimulating.value, isFalse);
      expect(service.progress.value, equals(0.0));
    });

    test('switching presets updates currentPresetInfo reactively', () {
      service.selectedPreset.value = SimulationPreset.hydeParkLondon;
      expect(service.currentPresetInfo.title, equals('Hyde Park Serpentine'));
      expect(service.currentPresetInfo.city, equals('London, UK'));

      service.selectedPreset.value = SimulationPreset.presidioSF;
      expect(service.currentPresetInfo.title, equals('The Presidio Coast'));
      expect(service.currentPresetInfo.city, equals('San Francisco, USA'));
    });
  });

  group('SimulationService - Loop Waypoint Generator', () {
    test('generates valid closed loop with pointCount + 1 points', () {
      const centerLat = 40.7812;
      const centerLng = -73.9665;
      const radius = 85.0;
      const count = 36;

      final waypoints = service.generateLoopWaypoints(
        centerLat: centerLat,
        centerLng: centerLng,
        baseRadiusMeters: radius,
        pointCount: count,
      );

      expect(waypoints.length, equals(count + 1));

      final first = waypoints.first;
      final last = waypoints.last;

      // Verify loop closure: first point and last point must coincide
      expect((first.latitude - last.latitude).abs(), lessThan(0.000001));
      expect((first.longitude - last.longitude).abs(), lessThan(0.000001));
    });

    test('generates realistic runner metrics on every waypoint', () {
      final waypoints = service.generateLoopWaypoints(
        centerLat: 51.5048,
        centerLng: -0.1650,
        baseRadiusMeters: 80.0,
        pointCount: 20,
      );

      for (int i = 0; i < waypoints.length; i++) {
        final wp = waypoints[i];
        expect(wp.accuracy, equals(3.5));
        expect(wp.speed, equals(4.2)); // ~15 km/h pacing
        expect(wp.heading, inInclusiveRange(0.0, 360.0));
        expect(wp.altitude, greaterThan(0));

        if (i > 0) {
          final prev = waypoints[i - 1];
          expect(wp.timestamp.isAfter(prev.timestamp), isTrue);
        }
      }
    });

    test('waypoints feature organic non-circular perturbations', () {
      const centerLat = 37.7989;
      const centerLng = -122.4662;
      const radius = 90.0;

      final waypoints = service.generateLoopWaypoints(
        centerLat: centerLat,
        centerLng: centerLng,
        baseRadiusMeters: radius,
        pointCount: 36,
      );

      // Measure Euclidean distance deviations from center in degrees
      final distances = waypoints.map((wp) {
        final dLat = wp.latitude - centerLat;
        final dLng = wp.longitude - centerLng;
        return math.sqrt(dLat * dLat + dLng * dLng);
      }).toList();

      final minDist = distances.reduce(math.min);
      final maxDist = distances.reduce(math.max);

      // A sterile circle would have minDist == maxDist.
      // Organic perturbation ensures radius variation > 10%
      expect(maxDist, greaterThan(minDist * 1.10));
    });
  });

  group('SimulationService - State & Lifecycle', () {
    test('stopSimulation resets observables cleanly', () {
      service.isSimulating.value = true;
      service.progress.value = 0.65;
      service.currentPhase.value = 'Running Loop';

      service.stopSimulation();

      expect(service.isSimulating.value, isFalse);
      expect(service.progress.value, equals(0.0));
      expect(service.currentPhase.value, equals('Cancelled'));
    });

    test('SimulationResult holds complete evaluation & Monad testnet payload', () {
      final result = SimulationResult(
        presetTitle: 'Central Park Great Lawn',
        city: 'New York, USA',
        areaM2: 18450.0,
        distanceMeters: 520.0,
        duration: const Duration(minutes: 3, seconds: 25),
        simulatedMonadTx: '0x143a9b99f8d1',
        completedAt: DateTime.now(),
        coinsEarned: 100,
      );

      expect(result.presetTitle, equals('Central Park Great Lawn'));
      expect(result.city, equals('New York, USA'));
      expect(result.areaM2, equals(18450.0));
      expect(result.distanceMeters, equals(520.0));
      expect(result.coinsEarned, equals(100));
      expect(result.simulatedMonadTx, startsWith('0x143'));
    });
  });
}
