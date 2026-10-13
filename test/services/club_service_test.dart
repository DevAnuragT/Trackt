import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trackt/models/club/user_club_model.dart';
import 'package:trackt/services/club_service.dart';

void main() {
  test(
    'unauthenticated load reports an error and hides the previous account clubs',
    () async {
      final client = SupabaseClient('https://clubs.example', 'test-key');
      final service = ClubService(client: client);
      service.userClubs.add(
        UserClub(
          clubId: 'club-1',
          clubName: 'Riverside',
          referralCode: 'RIVER123',
          creatorId: 'founder',
          clubCreatedAt: DateTime(2026),
          joinedAt: DateTime(2026),
          memberCount: 2,
        ),
      );
      await service.getUserClubs();
      expect(service.userClubsError.value, contains('Sign in'));
      expect(service.userClubs, isEmpty);
      expect(service.isLoading.value, false);
      service.clearClubData();
      expect(service.userClubsError.value, isNull);
      expect(service.userClubs, isEmpty);
      await client.dispose();
    },
  );

  test(
    'failed member RPC is surfaced rather than returning an empty roster',
    () async {
      final client = SupabaseClient(
        'https://clubs.example',
        'test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"message":"Could not load members","code":"42501"}',
            403,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      final service = ClubService(client: client);
      await expectLater(
        service.getClubMembers('club-1'),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
    },
  );
}
