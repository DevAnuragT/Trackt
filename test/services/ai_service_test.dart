import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trackt/services/ai_service.dart';

void main() {
  test('explicitly disabled AI never makes a paid request', () async {
    final service = AiService(
      projectUrl: 'https://trackt.example',
      anonKey: 'public-anon',
      accessToken: () => 'session',
      enabled: false,
      client: MockClient((_) => throw StateError('Must not call the proxy')),
    );
    await expectLater(
      service.conquestRecap(
        city: 'London',
        areaSqMeters: 1200,
        distanceMeters: 520,
      ),
      throwsA(isA<AiRecapException>()),
    );
    service.onClose();
  });
  test(
    'sends only run data and Supabase session credentials to the proxy',
    () async {
      final service = AiService(
        projectUrl: 'https://trackt.example/',
        anonKey: 'public-anon',
        accessToken: () => 'session-token',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://trackt.example/functions/v1/conquest-ai',
          );
          expect(request.headers['Authorization'], 'Bearer session-token');
          expect(request.headers['apikey'], 'public-anon');
          expect(jsonDecode(request.body), {
            'city': 'London',
            'areaSqMeters': 1200.0,
            'distanceMeters': 520.0,
          });
          return http.Response(
            jsonEncode({
              'message': 'New streets, new crown.',
              'source': 'kimi',
              'model': 'kimi-k2.6',
            }),
            200,
          );
        }),
      );
      final recap = await service.conquestRecap(
        city: 'London',
        areaSqMeters: 1200,
        distanceMeters: 520,
      );
      expect(recap.message, 'New streets, new crown.');
      expect(recap.model, 'kimi-k2.6');
      service.onClose();
    },
  );

  test('anonymous demos never call the paid AI proxy', () async {
    final service = AiService(
      projectUrl: 'https://trackt.example',
      anonKey: 'public-anon',
      accessToken: () => null,
      client: MockClient((_) => throw StateError('Must not call the proxy')),
    );
    await expectLater(
      service.conquestRecap(
        city: 'London',
        areaSqMeters: 1200,
        distanceMeters: 520,
      ),
      throwsA(isA<AiRecapException>()),
    );
    service.onClose();
  });

  test(
    'surfaces quota/credit errors instead of fabricating KIMI output',
    () async {
      final service = AiService(
        projectUrl: 'https://trackt.example',
        anonKey: 'public-anon',
        accessToken: () => 'session-token',
        client: MockClient(
          (_) async => http.Response(
            '{"error":"KIMI provider credits or quota are unavailable."}',
            503,
          ),
        ),
      );
      await expectLater(
        service.conquestRecap(
          city: 'London',
          areaSqMeters: 1200,
          distanceMeters: 520,
        ),
        throwsA(
          isA<AiRecapException>().having(
            (error) => error.message,
            'message',
            contains('credits or quota'),
          ),
        ),
      );
      service.onClose();
    },
  );

  test(
    'rejects missing provenance, empty output and malformed responses',
    () async {
      for (final body in [
        '{"message":"fake","source":"fallback","model":"kimi-k2.6"}',
        '{"message":"","source":"kimi","model":"kimi-k2.6"}',
        'not-json',
      ]) {
        final service = AiService(
          projectUrl: 'https://trackt.example',
          anonKey: 'public-anon',
          accessToken: () => 'session-token',
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          service.conquestRecap(
            city: 'London',
            areaSqMeters: 1200,
            distanceMeters: 520,
          ),
          throwsA(isA<AiRecapException>()),
        );
        service.onClose();
      }
    },
  );
}
