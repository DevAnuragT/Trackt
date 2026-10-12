import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackt/services/ai_service.dart';
import 'package:trackt/services/simulation_service.dart';
import 'package:trackt/views/map/components/simulation_victory_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  SimulationResult result() => SimulationResult(
    presetTitle: 'Central Park',
    city: 'New York',
    areaM2: 1200,
    distanceMeters: 520,
    duration: const Duration(minutes: 3),
    simulatedMonadTx: '0xlocal',
    completedAt: DateTime(2026),
  );

  testWidgets('recap and settlement remain scrollable on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: SimulationVictoryDialog(result: result())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Territory Conquered!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('victory renders immediately while the AI request is pending', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    int calls = 0;
    Get.put(
      AiService(
        projectUrl: 'https://trackt.example',
        anonKey: 'public-anon',
        accessToken: () => 'session',
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: SimulationVictoryDialog(result: result())),
      ),
    );
    expect(find.text('Territory Conquered!'), findsOneWidget);
    expect(find.text('Generating your conquest recap...'), findsOneWidget);
    response.complete(
      http.Response(
        '{"message":"New streets, new crown.","source":"kimi","model":"kimi-k2.6"}',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New streets, new crown.'), findsOneWidget);
    expect(find.text('KIMI recap'), findsOneWidget);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets(
    'anonymous victory stays usable without a paid request or fake AI label',
    (tester) async {
      Get.put(
        AiService(
          projectUrl: 'https://trackt.example',
          anonKey: 'public-anon',
          accessToken: () => null,
          client: MockClient((_) => throw StateError('Must not request AI')),
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: SimulationVictoryDialog(result: result())),
        ),
      );
      expect(find.text('Sign in for a KIMI conquest recap.'), findsOneWidget);
      expect(find.text('KIMI recap'), findsNothing);
      expect(
        find.text('Local proof only. On-chain settlement is not verified.'),
        findsOneWidget,
      );
      expect(find.text('View on Monad Explorer'), findsNothing);
    },
  );
}
