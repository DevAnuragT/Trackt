import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trackt/controllers/map/territory_display_controller.dart';
import 'package:trackt/models/territory/territory_model.dart';
import 'package:trackt/services/database_service.dart';
import 'package:trackt/services/run_history_service.dart';
import 'package:trackt/services/territory_service.dart';
import 'package:trackt/views/map/components/bottom_sheet_widget.dart';

class _Database extends DatabaseService {
  @override
  String? get currentUserId => 'user-1';
  @override
  Future<Map<String, dynamic>?> getUserStatistics([String? userId]) async => {
    'total_runs': 2,
  };
}

class _History extends TerritoryHistoryService {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Territories extends TerritoryService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
}

class _Map extends TerritoryDisplayController {
  bool fail = false;
  Territory? focused;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> flyToTerritory(Territory territory) async {
    if (fail) throw StateError('map unavailable');
    focused = territory;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  Future<_Map> setup(WidgetTester tester) async {
    Get.reset();
    Get.put<DatabaseService>(_Database());
    Get.put<TerritoryService>(_Territories());
    final history = _History();
    history.recentTerritories.add(
      Territory(
        id: 'recent',
        ownerId: 'user-1',
        boundaryPoints: [],
        area: 18,
        createdAt: DateTime.now(),
        center: LatLngPoint(
          latitude: 40,
          longitude: -73,
          timestamp: DateTime.now(),
        ),
      ),
    );
    history.allTerritories.assignAll(history.recentTerritories);
    Get.put<TerritoryHistoryService>(history);
    final map = _Map();
    Get.put<TerritoryDisplayController>(map);
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: Stack(children: [TerritoryBottomSheet()])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('18 m²').last);
    await tester.pumpAndSettle();
    return map;
  }

  testWidgets(
    'a recent-territory focus collapses the persistent sheet without popping home',
    (tester) async {
      final map = await setup(tester);
      await tester.tap(find.text('18 m²').last);
      await tester.pumpAndSettle();
      expect(map.focused?.id, 'recent');
      expect(find.byType(TerritoryBottomSheet), findsOneWidget);
      expect(find.text('18 m² territory focused'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a map failure is surfaced without an overlay exception or route pop',
    (tester) async {
      final map = await setup(tester);
      map.fail = true;
      await tester.tap(find.text('18 m²').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not focus the map. Try again shortly.'),
        findsOneWidget,
      );
      expect(find.byType(TerritoryBottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
