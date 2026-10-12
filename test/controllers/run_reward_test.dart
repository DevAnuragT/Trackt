import 'package:flutter_test/flutter_test.dart';
import 'package:trackt/controllers/map/run_tracker_controller.dart';

void main() {
  group('computeRunReward (variable + minimum)', () {
    test('runs below the minimum distance earn nothing', () {
      expect(
        RunTrackerController.computeRunReward(areaSqMeters: 5000, distanceMeters: 50),
        0,
      );
    });

    test('zero area earns nothing', () {
      expect(
        RunTrackerController.computeRunReward(areaSqMeters: 0, distanceMeters: 800),
        0,
      );
    });

    test('reward scales with distance and area', () {
      final small = RunTrackerController.computeRunReward(
          areaSqMeters: 4000, distanceMeters: 400);
      final big = RunTrackerController.computeRunReward(
          areaSqMeters: 40000, distanceMeters: 2000);
      expect(big, greaterThan(small));
    });

    test('reward is clamped to the [25, 1000] range', () {
      final tiny = RunTrackerController.computeRunReward(
          areaSqMeters: 10, distanceMeters: 120);
      final huge = RunTrackerController.computeRunReward(
          areaSqMeters: 5000000, distanceMeters: 100000);
      expect(tiny, greaterThanOrEqualTo(25));
      expect(huge, lessThanOrEqualTo(1000));
    });

    test('a typical Central Park loop earns a sensible amount', () {
      final r = RunTrackerController.computeRunReward(
          areaSqMeters: 16850, distanceMeters: 520);
      expect(r, inInclusiveRange(100, 130));
    });
  });
}
