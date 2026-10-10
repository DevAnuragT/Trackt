import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trackt/services/simulation_service.dart';
import 'package:trackt/views/map/components/simulation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SimulationService simService;

  setUp(() {
    Get.reset();
    simService = Get.put(SimulationService());
  });

  tearDown(() {
    simService.stopSimulation();
    Get.reset();
  });

  testWidgets('SimulationSheet renders header, presets, speed chips, and action button', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(
          body: SimulationSheet(),
        ),
      ),
    );

    // Verify Header Elements
    expect(find.text('Judge Simulation Lab'), findsOneWidget);
    expect(find.text('Metropolis Evaluation Engine'), findsOneWidget);
    expect(find.text('MONAD TESTNET'), findsOneWidget);

    // Verify Presets are listed
    expect(find.text('Central Park Great Lawn'), findsOneWidget);
    expect(find.text('Hyde Park Serpentine'), findsOneWidget);
    expect(find.text('The Presidio Coast'), findsOneWidget);
    expect(find.text('Local Proximity Loop'), findsOneWidget);

    // Verify Speed Chips are visible
    expect(find.text('⚡ Turbo'), findsOneWidget);
    expect(find.text('🎬 Demo'), findsOneWidget);
    expect(find.text('🏃 Natural'), findsOneWidget);

    // Verify Action button
    expect(find.text('Launch Simulated Run'), findsOneWidget);
  });

  testWidgets('SimulationSheet updates selectedSpeed when tapping speed chips', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(
          body: SimulationSheet(),
        ),
      ),
    );

    expect(simService.selectedSpeed.value, equals(SimulationSpeed.turbo));

    // Tap Demo speed
    await tester.tap(find.text('🎬 Demo'));
    await tester.pump();
    expect(simService.selectedSpeed.value, equals(SimulationSpeed.demo));

    // Tap Natural speed
    await tester.tap(find.text('🏃 Natural'));
    await tester.pump();
    expect(simService.selectedSpeed.value, equals(SimulationSpeed.natural));
  });

  testWidgets('SimulationSheet updates selectedPreset when tapping preset item', (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(
          body: SimulationSheet(),
        ),
      ),
    );

    expect(simService.selectedPreset.value, equals(SimulationPreset.centralParkNYC));

    // Tap Hyde Park Serpentine
    await tester.tap(find.text('Hyde Park Serpentine'));
    await tester.pump();
    expect(simService.selectedPreset.value, equals(SimulationPreset.hydeParkLondon));
  });
}
