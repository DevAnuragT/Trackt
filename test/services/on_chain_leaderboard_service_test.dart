import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackt/services/on_chain_leaderboard_service.dart';

void main() {
  test(
    'queries actual indexed players and preserves exact BigInt areas',
    () async {
      final service = OnChainLeaderboardService(
        endpoint: 'https://indexer.example/graphql',
        client: MockClient((request) async {
          final query = jsonDecode(request.body)['query'] as String;
          expect(query, contains('territoryCount: {_gt: 0}'));
          expect(query, contains('totalArea: desc'));
          expect(query, contains('limit: 20'));
          return http.Response(
            jsonEncode({
              'data': {
                'Player': [
                  {
                    'address': '0x1111111111111111111111111111111111111111',
                    'territoryCount': 3,
                    'totalArea': '9007199254740993123',
                    'conquestCount': 2,
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      final runners = await service.fetchLeaderboard();
      expect(runners.single.totalArea, BigInt.parse('9007199254740993123'));
      expect(runners.single.territoryCount, 3);
      service.onClose();
    },
  );

  test(
    'unconfigured and insecure endpoints are errors, not seeded rankings',
    () async {
      for (final endpoint in ['', 'http://indexer.example/graphql']) {
        final service = OnChainLeaderboardService(endpoint: endpoint);
        await expectLater(
          service.fetchLeaderboard(),
          throwsA(isA<LeaderboardException>()),
        );
        service.onClose();
      }
    },
  );

  test('an empty real index is distinguishable from an error', () async {
    final service = OnChainLeaderboardService(
      endpoint: 'https://indexer.example/graphql',
      client: MockClient(
        (_) async => http.Response('{"data":{"Player":[]}}', 200),
      ),
    );
    expect(await service.fetchLeaderboard(), isEmpty);
    service.onClose();
  });

  test(
    'surfaces GraphQL, HTTP and invalid-shape errors without silent defaults',
    () async {
      for (final response in [
        http.Response('{"errors":[{"message":"wrong schema"}]}', 200),
        http.Response('service unavailable', 503),
        http.Response('{"data":{}}', 200),
        http.Response('{"data":{"Player":[{"address":"invalid"}]}}', 200),
      ]) {
        final service = OnChainLeaderboardService(
          endpoint: 'https://indexer.example/graphql',
          client: MockClient((_) async => response),
        );
        await expectLater(
          service.fetchLeaderboard(),
          throwsA(isA<LeaderboardException>()),
        );
        service.onClose();
      }
    },
  );
}
