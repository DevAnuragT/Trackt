import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trackt/services/database_service.dart';

void main() {
  test('progress accepts the deployed object shape or single-row shape', () async {
    for (final response in [
      '{"total_distance_today":500,"total_minutes_today":10,"completed":true,"coins":100}',
      '[{"total_distance_today":500,"total_minutes_today":10,"completed":true,"coins":100}]',
    ]) {
      final client = SupabaseClient(
        'https://challenge.example',
        'test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            response,
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      expect(
        (await DatabaseService(
          client: client,
        ).fetchDailyChallengeProgress())?['completed'],
        true,
      );
      await client.dispose();
    }
  });

  test(
    'failed progress never falls back to an old/undated challenge row',
    () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://challenge.example',
        'test-key',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            '{"code":"PGRST202","message":"Missing RPC"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await expectLater(
        DatabaseService(client: client).fetchDailyChallengeProgress(),
        throwsA(isA<PostgrestException>()),
      );
      expect(paths, ['/rest/v1/rpc/get_daily_challenge_progress']);
      await client.dispose();
    },
  );

  test(
    'run insert sends exact observed distance and whole active minutes',
    () async {
      final client = SupabaseClient(
        'https://challenge.example',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/create_run_and_maybe_award');
          expect(jsonDecode(request.body), {
            'p_duration_minutes': 10,
            'p_distance_meters': 500.25,
          });
          return http.Response(
            '{"awarded":true,"coins":100}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final result = await DatabaseService(
        client: client,
      ).createRunAndMaybeAward(durationMinutes: 10, distanceMeters: 500.25);
      expect(result?['awarded'], true);
      await client.dispose();
    },
  );

  test('failed insert and invalid success shapes are surfaced', () async {
    for (final entry in [
      (503, '{"message":"Unavailable","code":"server"}'),
      (200, 'null'),
    ]) {
      final client = SupabaseClient(
        'https://challenge.example',
        'test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            entry.$2,
            entry.$1,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        DatabaseService(
          client: client,
        ).createRunAndMaybeAward(durationMinutes: 10, distanceMeters: 500),
        throwsA(anyOf(isA<PostgrestException>(), isA<FormatException>())),
      );
      await client.dispose();
    }
  });
}
