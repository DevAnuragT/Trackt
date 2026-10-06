// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test - MaterialApp builds', (WidgetTester tester) async {
    // Build a simple MaterialApp to verify Flutter is working
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Test App')),
          body: const Center(child: Text('Hello Test')),
        ),
      ),
    );

    // Verify the basic widgets are present
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Test App'), findsOneWidget);
    expect(find.text('Hello Test'), findsOneWidget);
  });
}
