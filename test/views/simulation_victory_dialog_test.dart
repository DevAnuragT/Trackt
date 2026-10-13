import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trackt/services/simulation_service.dart';
import 'package:trackt/views/map/components/simulation_victory_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'victory fits a small screen without an AI recap or fabricated settlement',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = SimulationResult(
        presetTitle: 'Central Park',
        city: 'New York',
        areaM2: 1200,
        distanceMeters: 520,
        duration: const Duration(minutes: 3),
        simulatedMonadTx: '0xlocal',
        completedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: SimulationVictoryDialog(result: result)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Territory Conquered!'), findsOneWidget);
      expect(find.text('Conquest recap'), findsNothing);
      expect(find.text('KIMI recap'), findsNothing);
      expect(
        find.text('Local proof only. On-chain settlement is not verified.'),
        findsOneWidget,
      );
      expect(find.text('View on Monad Explorer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SimulationVictoryDialog displays metrics and Monad Testnet details',
    (WidgetTester tester) async {
      final result = SimulationResult(
        presetTitle: 'Central Park Great Lawn',
        city: 'New York, USA',
        areaM2: 16850.0,
        distanceMeters: 520.0,
        duration: const Duration(minutes: 3, seconds: 45),
        simulatedMonadTx: '0x143a9b1234567890abcdef',
        completedAt: DateTime.now(),
        coinsEarned: 100,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: SimulationVictoryDialog(result: result)),
        ),
      );

      // Verify Title & Location
      expect(find.text('Territory Conquered!'), findsOneWidget);
      expect(
        find.text('Central Park Great Lawn • New York, USA'),
        findsOneWidget,
      );
      expect(find.text('MONAD METROPOLIS DEMO'), findsOneWidget);

      // Verify Conquered Metrics
      expect(find.text('16850 m²'), findsOneWidget);
      expect(find.text('520 m'), findsOneWidget);
      expect(find.text('03:45'), findsOneWidget);
      expect(find.text('+100 \$TRACKT'), findsOneWidget);

      // Verify Monad Testnet Section
      expect(find.text('Monad Testnet (Chain ID 10143)'), findsOneWidget);
      expect(find.text('10,000 TPS'), findsOneWidget);
      expect(find.textContaining('0x143a9b'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('View Territory on Map'), findsOneWidget);
      expect(find.text('Close Details'), findsOneWidget);
    },
  );

  testWidgets(
    'SimulationVictoryDialog shows explorer button when explorerUrl set',
    (WidgetTester tester) async {
      final result = SimulationResult(
        presetTitle: 'Hyde Park Serpentine',
        city: 'London, UK',
        areaM2: 15000.0,
        distanceMeters: 480.0,
        duration: const Duration(minutes: 2, seconds: 30),
        simulatedMonadTx: '0xabc123',
        completedAt: DateTime.now(),
        coinsEarned: 100,
        explorerUrl: 'https://testnet.monadexplorer.com/tx/0xabc123',
        settledOnChain: true,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: SimulationVictoryDialog(result: result)),
        ),
      );

      expect(find.text('View on Monad Explorer'), findsOneWidget);
      expect(find.textContaining('Broadcast on-chain'), findsOneWidget);
    },
  );

  testWidgets(
    'SimulationVictoryDialog hides explorer button when explorerUrl null',
    (WidgetTester tester) async {
      final result = SimulationResult(
        presetTitle: 'The Presidio Coast',
        city: 'San Francisco, USA',
        areaM2: 15000.0,
        distanceMeters: 510.0,
        duration: const Duration(minutes: 2, seconds: 50),
        simulatedMonadTx: '0xdef456',
        completedAt: DateTime.now(),
        coinsEarned: 100,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: SimulationVictoryDialog(result: result)),
        ),
      );

      expect(find.text('View on Monad Explorer'), findsNothing);
    },
  );
}
