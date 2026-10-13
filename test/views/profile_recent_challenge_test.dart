import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trackt/core/theme/app_colors.dart';
import 'package:trackt/models/territory/territory_model.dart';
import 'package:trackt/services/daily_challenge_service.dart';
import 'package:trackt/services/run_history_service.dart';
import 'package:trackt/services/user_preferences_service.dart';
import 'package:trackt/views/daily_quests/daily_quests_view.dart';
import 'package:trackt/views/map/components/recent_territories_section.dart';
import 'package:trackt/views/profile_view.dart';
import 'package:trackt/views/profile/run_history_page.dart';

import '../services/daily_challenge_service_test.dart' show ChallengeDatabase;

class _Preferences extends UserPreferencesService {
  int refreshes = 0;
  String? savedName;
  bool failSave = false;
  _Preferences() {
    username.value = 'runner';
    userCoins.value = 350;
  }
  @override
  Future<void> setUsername(String name) async {
    if (failSave) throw StateError('username_taken');
    savedName = name;
    username.value = name;
  }

  @override
  Future<void> forceRefreshProfile() async {
    refreshes++;
    username.value = 'server_name';
  }
}

class _History extends TerritoryHistoryService {
  int refreshes = 0;
  @override
  // Avoid cloud loading in this layout fixture.
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshTerritories() async {
    refreshes++;
    hasError.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  Future<void> page(
    WidgetTester tester,
    Widget widget, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: widget,
      ),
    );
    await tester.pumpAndSettle();
  }

  User user() => User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-01',
    email: 'long.runner.email.address@example.test',
  );
  ProfileView profile(_Preferences prefs) =>
      ProfileView(preferences: prefs, currentUser: user);
  Territory territory(double area, {String owner = 'user-1'}) => Territory(
    id: 'territory-$area',
    ownerId: owner,
    boundaryPoints: [],
    area: area,
    createdAt: DateTime.now(),
    center: LatLngPoint(
      latitude: 40,
      longitude: -73,
      timestamp: DateTime.now(),
    ),
  );

  testWidgets('profile is professional and scrollable at large text', (
    tester,
  ) async {
    final prefs = _Preferences()
      ..username.value = 'A long profile display name';
    await page(tester, profile(prefs), scale: 2);
    expect(find.text('350 in-game coins'), findsOneWidget);
    expect(
      find.text('Shop balance, separate from wallet tokens.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Custom color'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile username rejects invalid input and preserves failed server edits',
    (tester) async {
      final prefs = _Preferences();
      await page(tester, profile(prefs));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bad name!');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save username'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save username'));
      await tester.pumpAndSettle();
      expect(prefs.savedName, isNull);
      expect(find.textContaining('Use 3-20 characters'), findsOneWidget);
      prefs.failSave = true;
      await tester.enterText(find.byType(TextField), 'valid_name');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save username'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save username'));
      await tester.pumpAndSettle();
      expect(find.text('Username already taken'), findsOneWidget);
      expect(prefs.username.value, 'runner');
    },
  );

  testWidgets(
    'profile saves a valid name and disables the save button afterward',
    (tester) async {
      final prefs = _Preferences();
      await page(tester, profile(prefs));
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'updated_runner');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save username'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save username'));
      await tester.pumpAndSettle();
      expect(prefs.savedName, 'updated_runner');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save username'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('profile custom colors remain purchase-gated', (tester) async {
    final prefs = _Preferences();
    await page(tester, profile(prefs));
    await tester.scrollUntilVisible(
      find.text('Custom color'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Custom color'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom color'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unlock custom territory colors'),
      findsOneWidget,
    );
    expect(find.text('Custom territory color'), findsNothing);
  });

  testWidgets(
    'profile color change and sign out can be cancelled without modifying data',
    (tester) async {
      final prefs = _Preferences();
      final original = prefs.userColor.value;
      await page(tester, profile(prefs));
      await tester.scrollUntilVisible(
        find.byTooltip('Green'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byTooltip('Green'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Green'));
      await tester.pumpAndSettle();
      expect(find.text('Change territory color?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.userColor.value, original);
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Sign out'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);
    },
  );

  testWidgets('profile activity links still open territory history', (
    tester,
  ) async {
    Get.put<TerritoryHistoryService>(_History());
    await page(tester, profile(_Preferences()));
    await tester.ensureVisible(find.text('Territory history'));
    await tester.tap(find.text('Territory history'));
    await tester.pumpAndSettle();
    expect(find.byType(TerritoryHistoryPage), findsOneWidget);
  });

  testWidgets(
    'signed-out profile provides sign in instead of account controls',
    (tester) async {
      await page(
        tester,
        ProfileView(preferences: _Preferences(), currentUser: () => null),
      );
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Save username'), findsNothing);
    },
  );

  testWidgets(
    'recent territories show accurate small areas and do not invent partial losses',
    (tester) async {
      final history = _History();
      history.recentTerritories.assignAll([
        territory(14),
        territory(25463),
        territory(90, owner: 'another'),
      ]);
      Territory? selected;
      await page(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RecentTerritoriesSection(
              history: history,
              currentUserId: 'user-1',
              onSelect: (territory) async {
                selected = territory;
              },
            ),
          ),
        ),
        scale: 2,
      );
      expect(find.text('14 m²'), findsOneWidget);
      await tester.ensureVisible(find.text('2.55 ha'));
      await tester.tap(find.text('2.55 ha'));
      expect(selected?.area, 25463);
      await tester.scrollUntilVisible(find.text('No longer owned'), 200);
      expect(find.text('Territory partially lost'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recent territories distinguish empty, loading and failed states',
    (tester) async {
      final history = _History();
      await page(
        tester,
        Scaffold(
          body: RecentTerritoriesSection(
            history: history,
            currentUserId: null,
            onSelect: (_) async {},
          ),
        ),
      );
      expect(find.text('No territories yet'), findsOneWidget);
      history.hasError.value = true;
      await tester.pump();
      expect(find.text('No territories yet'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(history.refreshes, 1);
      history.isLoading.value = true;
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('No territories yet'), findsNothing);
    },
  );

  test('territory area display uses correct measurable unit boundaries', () {
    expect(TerritoryHistoryService.displayArea(14), '14 m²');
    expect(TerritoryHistoryService.displayArea(9999), '9999 m²');
    expect(TerritoryHistoryService.displayArea(10000), '1.00 ha');
    expect(TerritoryHistoryService.displayArea(1000000), '1.00 km²');
  });

  testWidgets(
    'challenge displays real cumulative totals and no fabricated completion time',
    (tester) async {
      final db = ChallengeDatabase()
        ..progress = {
          'total_distance_today': 510,
          'total_minutes_today': 11,
          'completed': true,
          'coins': 100,
        };
      Get.put(DailyChallengeService(database: db, saveCoins: (_) async {}));
      await page(tester, const DailyQuestsView(), scale: 2);
      expect(find.text('Completed today'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('510 / 500 m'), 150);
      expect(find.text('510 / 500 m'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Judge Demo simulations'),
        180,
      );
      expect(find.textContaining('Completed at'), findsNothing);
      expect(tester.takeException(), isNull);
      Get.find<DailyChallengeService>().onClose();
    },
  );

  testWidgets('challenge error is visible and retry fetches new progress', (
    tester,
  ) async {
    final db = ChallengeDatabase()..failFetch = true;
    Get.put(DailyChallengeService(database: db, saveCoins: (_) async {}));
    await page(tester, const DailyQuestsView());
    await tester.scrollUntilVisible(find.text('Retry'), 160);
    db.failFetch = false;
    db.progress = {
      'total_distance_today': 250,
      'total_minutes_today': 4,
      'completed': false,
      'coins': 0,
    };
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('250 / 500 m'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(db.fetches, 2);
    Get.find<DailyChallengeService>().onClose();
  });
}
