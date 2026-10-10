import 'package:flutter_test/flutter_test.dart';
import 'package:trackt/controllers/map/run_tracker_controller.dart';

void main() {
  group('Anti-cheat: isImplausibleRunningSpeed', () {
    test('accepts a normal running pace (~12 km/h)', () {
      // 10 m in 3 s = 3.33 m/s = 12 km/h.
      expect(RunTrackerController.isImplausibleRunningSpeed(10, 3), isFalse);
    });

    test('accepts right at the sprint boundary (~24 km/h)', () {
      // 20 m in 3 s = 6.67 m/s = 24 km/h, below the 25 km/h cap.
      expect(RunTrackerController.isImplausibleRunningSpeed(20, 3), isFalse);
    });

    test('rejects vehicle speed (~72 km/h)', () {
      // 100 m in 5 s = 20 m/s = 72 km/h.
      expect(RunTrackerController.isImplausibleRunningSpeed(100, 5), isTrue);
    });

    test('rejects a teleport jump over a tiny interval', () {
      // 500 m in 1 s = 1800 km/h.
      expect(RunTrackerController.isImplausibleRunningSpeed(500, 1), isTrue);
    });

    test('cannot judge non-positive time delta (returns false)', () {
      expect(RunTrackerController.isImplausibleRunningSpeed(100, 0), isFalse);
      expect(RunTrackerController.isImplausibleRunningSpeed(100, -2), isFalse);
    });
  });
}
