import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/controllers/main_navigation_controller.dart';
import 'package:trackt/controllers/map/run_tracker_controller.dart';
import 'package:trackt/services/daily_challenge_service.dart';
import 'package:trackt/services/database_service.dart';
import 'package:trackt/services/user_preferences_service.dart';

class ChallengeDatabase extends DatabaseService {
  String? userId = 'user-1';
  int fetches = 0;
  int insertions = 0;
  bool failFetch = false;
  bool failInsert = false;
  Completer<Map<String, dynamic>?>? request;
  Map<String, dynamic> progress = {
    'total_distance_today': 0,
    'total_minutes_today': 0,
    'completed': false,
    'coins': 0,
  };
  Map<String, dynamic> result = {
    'total_distance_today': 500,
    'total_minutes_today': 10,
    'awarded': true,
    'coins': 100,
  };
  @override
  String? get dailyChallengeCurrentUserId => userId;
  @override
  String? get currentUserId => userId;
  @override
  Future<Map<String, dynamic>?> fetchDailyChallengeProgress() async {
    fetches++;
    if (failFetch) throw StateError('network');
    return request?.future ?? progress;
  }

  @override
  Future<Map<String, dynamic>?> createRunAndMaybeAward({
    required int durationMinutes,
    required double distanceMeters,
  }) async {
    insertions++;
    if (failInsert) throw StateError('server error');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChallengeDatabase database;
  late DailyChallengeService challenge;
  late DateTime now;
  final coins = <int>[];

  setUp(() {
    Get.reset();
    database = ChallengeDatabase();
    now = DateTime.utc(2026, 10, 13, 10);
    coins.clear();
    challenge = DailyChallengeService(
      database: database,
      now: () => now,
      saveCoins: (value) async {
        coins.add(value);
      },
    );
  });
  tearDown(() {
    challenge.onClose();
    Get.reset();
  });

  Future<bool> record({String id = 'run-1', bool simulation = false}) =>
      challenge.recordCompletedRun(
        runId: id,
        duration: const Duration(minutes: 10),
        distanceMeters: 500,
        isSimulation: simulation,
      );

  test(
    'real cumulative progress and authoritative coins update from a completed run',
    () async {
      expect(await record(), true);
      expect(challenge.distanceMetersToday.value, 500);
      expect(challenge.durationMinutesToday.value, 10);
      expect(challenge.isCompletedToday.value, true);
      expect(
        challenge.completedAt.value,
        isNull,
        reason: 'Do not invent a server completion time',
      );
      expect(coins.single, 100);
    },
  );

  test(
    'simulated runs cannot insert daily progress even after simulation UI ends',
    () async {
      expect(await record(simulation: true), false);
      expect(database.insertions, 0);
      expect(challenge.distanceMetersToday.value, 0);
      expect(coins, isEmpty);
    },
  );

  test('repeated callbacks for the same run do not insert twice', () async {
    await record();
    await record();
    expect(database.insertions, 1);
  });

  test('failed insertion is visible and is not blindly replayed', () async {
    database.failInsert = true;
    expect(await record(), false);
    expect(challenge.error.value, contains('sync failed'));
    expect(challenge.isCompletedToday.value, false);
    await record();
    expect(database.insertions, 1);
    expect(coins, isEmpty);
  });

  test(
    'later no-award run does not clear today’s already completed challenge',
    () async {
      await record();
      database.result = {
        'awarded': false,
        'total_distance_today': 600,
        'total_minutes_today': 12,
        'coins': 100,
      };
      expect(await record(id: 'run-2'), false);
      expect(challenge.isCompletedToday.value, true);
      expect(challenge.distanceMetersToday.value, 600);
    },
  );

  test('failed refresh keeps known progress with an explicit error', () async {
    await record();
    database.failFetch = true;
    await challenge.refreshFromServer(force: true);
    expect(challenge.isCompletedToday.value, true);
    expect(challenge.distanceMetersToday.value, 500);
    expect(challenge.error.value, contains('Could not load'));
  });

  test(
    'midnight UTC resets completion and progress before fetching a new day',
    () async {
      await record();
      now = DateTime.utc(2026, 10, 14);
      await challenge.refreshFromServer();
      expect(challenge.isCompletedToday.value, false);
      expect(challenge.distanceMetersToday.value, 0);
      expect(database.fetches, 1);
    },
  );

  test(
    'user switch clears old progress and ignores an old user’s pending response',
    () async {
      database.request = Completer<Map<String, dynamic>?>();
      final pending = challenge.refreshFromServer();
      database.userId = 'user-2';
      database.request!.complete({
        'total_distance_today': 1000,
        'total_minutes_today': 20,
        'completed': true,
        'coins': 1000,
      });
      await pending;
      expect(challenge.isCompletedToday.value, false);
      expect(challenge.distanceMetersToday.value, 0);
      expect(coins, isEmpty);
    },
  );

  test('stale fetch cannot overwrite a newer run result', () async {
    database.request = Completer<Map<String, dynamic>?>();
    final pending = challenge.refreshFromServer();
    await record();
    database.request!.complete(database.progress);
    await pending;
    expect(challenge.distanceMetersToday.value, 500);
    expect(challenge.isCompletedToday.value, true);
  });

  test(
    'cache lasts 30 seconds, not a whole day, and explicit refresh bypasses it',
    () async {
      await challenge.refreshFromServer();
      await challenge.refreshFromServer();
      expect(database.fetches, 1);
      now = now.add(const Duration(seconds: 31));
      await challenge.refreshFromServer();
      expect(database.fetches, 2);
      await challenge.refreshFromServer(force: true);
      expect(database.fetches, 3);
    },
  );

  test('opening the Quests tab forces a refresh of cached progress', () async {
    Get.put<DailyChallengeService>(challenge);
    final nav = MainNavigationController();
    await challenge.refreshFromServer();
    nav.changeTab(2);
    await Future<void>.delayed(Duration.zero);
    expect(database.fetches, 2);
  });

  test('server coins persist locally without another server write', () async {
    SharedPreferences.setMockInitialValues({'userCoins': 20});
    final prefs = await UserPreferencesService().init();
    await prefs.applyServerCoins(120);
    expect(prefs.userCoins.value, 120);
    expect((await SharedPreferences.getInstance()).getInt('userCoins'), 120);
  });

  test(
    'malformed and absent backend data cannot masquerade as zero progress',
    () async {
      database.progress = {};
      await challenge.refreshFromServer();
      expect(challenge.error.value, isNotNull);
      expect(coins, isEmpty);
      database.userId = null;
      await challenge.refreshFromServer(force: true);
      expect(challenge.error.value, contains('Sign in'));
      expect(database.fetches, 1);
    },
  );

  test(
    'active run duration excludes accumulated and currently paused time',
    () {
      final start = DateTime.utc(2026, 10, 13, 10);
      expect(
        RunTrackerController.activeRunDuration(
          startedAt: start,
          now: start.add(const Duration(minutes: 15)),
          pausedDuration: const Duration(minutes: 6),
        ),
        const Duration(minutes: 9),
      );
      expect(
        RunTrackerController.activeRunDuration(
          startedAt: start,
          now: start.add(const Duration(minutes: 20)),
          pausedAt: start.add(const Duration(minutes: 15)),
          pausedDuration: const Duration(minutes: 6),
        ),
        const Duration(minutes: 9),
      );
    },
  );
}
