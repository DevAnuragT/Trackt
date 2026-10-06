import 'package:get/get.dart';
import 'database_service.dart';
import 'user_preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyChallengeService extends GetxService {
  final DatabaseService _databaseService = Get.find<DatabaseService>();

  final RxBool isCompletedToday = false.obs;
  final Rx<DateTime?> completedAt = Rx<DateTime?>(null);
  final RxInt rewardCoins = 100.obs;
  final RxDouble distanceMetersToday = 0.0.obs;
  final RxInt durationMinutesToday = 0.obs;
  static const double targetDistance = 500.0;
  static const int targetMinutes = 10;
  DateTime? _lastFetchUtcDate;
  String? _lastUserId; // track which user's data is loaded

  void _resetStateForNewUser(String? newUserId) {
    distanceMetersToday.value = 0.0;
    durationMinutesToday.value = 0;
    isCompletedToday.value = false;
    completedAt.value = null;
    rewardCoins.value = 100;
    _lastFetchUtcDate = null;
    _lastUserId = newUserId;
  }

  Future<void> refreshFromServer({bool force = false}) async {
    final nowUtc = DateTime.now().toUtc();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // If user changed, always reset and force fetch
    if (currentUserId != _lastUserId) {
      _resetStateForNewUser(currentUserId);
      force = true; // ensure fetch happens
    }

    if (!force && _lastFetchUtcDate != null && _sameDay(_lastFetchUtcDate!, nowUtc)) return;
    try {
      final data = await _databaseService.fetchDailyChallengeProgress();
      if (data != null) {
        distanceMetersToday.value = (data['total_distance_today'] as num?)?.toDouble() ?? 0.0;
        durationMinutesToday.value = (data['total_minutes_today'] as num?)?.toInt() ?? 0;
        isCompletedToday.value = data['completed'] == true;
        rewardCoins.value = (data['reward_coins'] as num?)?.toInt() ?? 100;
        // No completed_at in RPC yet; leave null unless completed
        if (isCompletedToday.value && completedAt.value == null) {
          completedAt.value = DateTime.now().toUtc();
        }
        _lastFetchUtcDate = nowUtc;
      }
    } catch (e) {
      print('⚠️ Failed to refresh daily challenge from server: $e');
    }
  }

  void applyRunResult(Map<String,dynamic>? result) {
    if (result == null) return;
    distanceMetersToday.value = (result['total_distance_today'] as num?)?.toDouble() ?? distanceMetersToday.value;
    durationMinutesToday.value = (result['total_minutes_today'] as num?)?.toInt() ?? durationMinutesToday.value;
    final awarded = result['awarded'] == true;
    if (awarded) {
      isCompletedToday.value = true;
      completedAt.value = DateTime.now().toUtc();
    }
    // Sync coins if provided
    if (result.containsKey('coins')) {
      final coinsVal = (result['coins'] as num?)?.toInt();
      if (coinsVal != null && Get.isRegistered<UserPreferencesService>()) {
        try {
          final prefs = Get.find<UserPreferencesService>();
            // Direct set without triggering extra server write (already authoritative)
          prefs.userCoins.value = coinsVal;
        } catch (_) {}
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year==b.year && a.month==b.month && a.day==b.day;

  String friendlyDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    String two(int n)=> n.toString().padLeft(2,'0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}
