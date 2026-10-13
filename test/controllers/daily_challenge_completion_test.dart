import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trackt/controllers/map/run_tracker_controller.dart';
import 'package:trackt/models/territory/run_session_model.dart';
import 'package:trackt/services/daily_challenge_service.dart';
import 'package:trackt/services/location_permission_service.dart';
import 'package:trackt/services/location_service.dart';
import 'package:trackt/services/run_storage_service.dart';
import 'package:trackt/services/samsung_permission_helper.dart';
import 'package:trackt/services/territory_service.dart';
import 'package:trackt/services/database_service.dart';

import '../services/daily_challenge_service_test.dart' show ChallengeDatabase;

class _Location extends LocationService {
  @override
  // Avoid real hardware initialization in the completed-run fixture.
  // ignore: must_call_super
  void onInit() {}
}

class _Territories extends TerritoryService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
}

class _Samsung extends SamsungPermissionHelper {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Storage extends RunStorageService {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> saveRun(RunSession session) async {}
}

class _Tracker extends RunTrackerController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  Future<(_Tracker, ChallengeDatabase)> setup(WidgetTester tester) async {
    Get.reset();
    Get.put<LocationService>(_Location());
    Get.put(LocationPermissionService());
    Get.put<RunStorageService>(_Storage());
    Get.put<TerritoryService>(_Territories());
    Get.put<SamsungPermissionHelper>(_Samsung());
    final db = ChallengeDatabase();
    Get.put<DatabaseService>(db);
    Get.put(DailyChallengeService(database: db, saveCoins: (_) async {}));
    final tracker = _Tracker();
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/home',
        getPages: [
          GetPage(
            name: '/home',
            page: () => const Scaffold(body: Text('Home')),
          ),
        ],
      ),
    );
    tracker.currentRunSession.value = RunSession(
      id: 'real-session',
      userId: 'user-1',
      startTime: DateTime.now(),
      rawPath: [],
      status: RunStatus.active,
    );
    tracker.totalDistance.value = 500;
    tracker.runDuration.value = const Duration(minutes: 10);
    tracker.isRunning.value = true;
    return (tracker, db);
  }

  testWidgets('real run records challenge before a no-territory early return', (
    tester,
  ) async {
    final (tracker, db) = await setup(tester);
    await tracker.stopRun();
    await tester.pumpAndSettle();
    expect(db.insertions, 1);
    expect(Get.find<DailyChallengeService>().isCompletedToday.value, true);
    await tracker.stopRun();
    expect(db.insertions, 1);
    tracker.onClose();
    Get.find<DailyChallengeService>().onClose();
  });

  testWidgets(
    'simulation and later navigation never record physical challenge credit',
    (tester) async {
      final (tracker, db) = await setup(tester);
      tracker.isSimulating.value = true;
      await tracker.stopRun();
      tracker.isSimulating.value = false;
      tracker.goToMainMap();
      await tester.pumpAndSettle();
      expect(db.insertions, 0);
      expect(Get.find<DailyChallengeService>().isCompletedToday.value, false);
      tracker.onClose();
      Get.find<DailyChallengeService>().onClose();
    },
  );

  testWidgets('switching accounts during a run cannot credit another account', (
    tester,
  ) async {
    final (tracker, db) = await setup(tester);
    db.userId = 'other-account';
    await tracker.stopRun();
    await tester.pumpAndSettle();
    expect(db.insertions, 0);
    expect(
      Get.find<DailyChallengeService>().error.value,
      contains('account changed'),
    );
    tracker.onClose();
    Get.find<DailyChallengeService>().onClose();
  });
}
