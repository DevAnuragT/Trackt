import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackt/services/on_chain_leaderboard_service.dart';
import 'package:trackt/views/on_chain_leaderboard_page.dart';

void main() {
  testWidgets('shows configuration errors rather than invented rankings', (
    tester,
  ) async {
    final service = OnChainLeaderboardService(endpoint: '');
    await tester.pumpWidget(
      MaterialApp(home: OnChainLeaderboardPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ENVIO_GRAPHQL_URL'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    service.onClose();
  });

  testWidgets('shows real indexed data without overflow on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = OnChainLeaderboardService(
      endpoint: 'https://indexer.example/graphql',
      client: MockClient(
        (_) async => http.Response(
          '{"data":{"Player":[{"address":"0x1111111111111111111111111111111111111111",'
          '"territoryCount":2,"totalArea":"9007199254740993123","conquestCount":1}]}}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: OnChainLeaderboardPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0x1111...1111'), findsOneWidget);
    expect(find.text('9007199254740993123 m²'), findsOneWidget);
    expect(tester.takeException(), isNull);
    service.onClose();
  });

  testWidgets('shows an empty chain state and allows a deliberate refresh', (
    tester,
  ) async {
    int calls = 0;
    final service = OnChainLeaderboardService(
      endpoint: 'https://indexer.example/graphql',
      client: MockClient((_) async {
        calls++;
        return http.Response('{"data":{"Player":[]}}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: OnChainLeaderboardPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No on-chain claims indexed yet'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Refresh standings'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    service.onClose();
  });
}
