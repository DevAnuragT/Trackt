import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/database_service.dart';
import 'package:trackt/services/user_preferences_service.dart';

class _ProfileDatabase extends DatabaseService {
  bool failName = false;
  String? savedName;
  Map<String, dynamic>? profile = {'display_name': 'runner', 'coins': 20};
  @override
  bool get isAuthenticated => true;
  @override
  Future<Map<String, dynamic>?> getUserProfile([String? userId]) async =>
      profile;
  @override
  Future<void> updateUserDisplayName(String name) async {
    if (failName) throw StateError('username_taken');
    savedName = name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a rejected cloud username cannot be saved locally as a successful update',
    () async {
      final database = _ProfileDatabase();
      final prefs = await UserPreferencesService(database: database).init();
      database.failName = true;
      await expectLater(prefs.setUsername('already_taken'), throwsStateError);
      expect(prefs.username.value, 'runner');
      expect(
        (await SharedPreferences.getInstance()).getString('username'),
        'runner',
      );
    },
  );

  test('accepted username updates both cloud and local preferences', () async {
    final database = _ProfileDatabase();
    final prefs = await UserPreferencesService(database: database).init();
    await prefs.setUsername('updated_runner');
    expect(database.savedName, 'updated_runner');
    expect(prefs.username.value, 'updated_runner');
    expect(
      (await SharedPreferences.getInstance()).getString('username'),
      'updated_runner',
    );
  });

  test(
    'profile refresh failure is surfaced and preserves the prior profile',
    () async {
      final database = _ProfileDatabase();
      final prefs = await UserPreferencesService(database: database).init();
      database.profile = null;
      await expectLater(prefs.forceRefreshProfile(), throwsStateError);
      expect(prefs.username.value, 'runner');
      expect(prefs.userCoins.value, 20);
    },
  );
}
