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

  testWidgets('SimulationVictoryDialog displays metrics and Monad Testnet details', (WidgetTester tester) async {
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
        home: Scaffold(
          body: SimulationVictoryDialog(result: result),
        ),
      ),
    );

    // Verify Title & Location
    expect(find.text('Territory Conquered!'), findsOneWidget);
    expect(find.text('Central Park Great Lawn • New York, USA'), findsOneWidget);
    expect(find.text('MONAD METROPOLIS DEMO'), findsOneWidget);

    // Verify Conquered Metrics
    expect(find.text('16850 m²'), findsOneWidget);
    expect(find.text('520 m'), findsOneWidget);
    expect(find.text('03:45'), findsOneWidget);
    expect(find.text('+100 \$TRACKT'), findsOneWidget);

    // Verify Monad Testnet Section
    expect(find.text('Monad Testnet (Chain ID 143)'), findsOneWidget);
    expect(find.text('10,000 TPS'), findsOneWidget);
    expect(find.textContaining('0x143a9b'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('View Territory on Map'), findsOneWidget);
    expect(find.text('Close Details'), findsOneWidget);
  });
}
