import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'database_service.dart';
import 'user_preferences_service.dart';

class DailyChallengeService extends GetxService with WidgetsBindingObserver {
  final DatabaseService _database;
  final DateTime Function() _now;
  final Future<void> Function(int)? _saveCoins;
  final RxBool isCompletedToday = false.obs;
  final Rx<DateTime?> completedAt = Rx<DateTime?>(null);
  final RxInt rewardCoins = 100.obs;
  final RxDouble distanceMetersToday = 0.0.obs;
  final RxInt durationMinutesToday = 0.obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();
  static const double targetDistance = 500;
  static const int targetMinutes = 10;
  DateTime? _day;
  DateTime? _lastFetch;
  String? _userId;
  int _revision = 0;
  Timer? _dayTimer;
  final Set<String> _recordedRuns = {};
  Future<void>? _refresh;
  bool _closed = false;

  DailyChallengeService({
    DatabaseService? database,
    DateTime Function()? now,
    Future<void> Function(int)? saveCoins,
  }) : _database = database ?? Get.find<DatabaseService>(),
       _now = now ?? DateTime.now,
       _saveCoins = saveCoins;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_syncIdentity()) unawaited(refreshFromServer(force: true));
    });
  }

  bool _syncIdentity() {
    final userId = _database.dailyChallengeCurrentUserId;
    final now = _now().toUtc();
    final day = DateTime.utc(now.year, now.month, now.day);
    if (userId == _userId && day == _day) return false;
    _userId = userId;
    _day = day;
    _lastFetch = null;
    _revision++;
    _recordedRuns.clear();
    distanceMetersToday.value = 0;
    durationMinutesToday.value = 0;
    isCompletedToday.value = false;
    completedAt.value = null;
    error.value = null;
    return true;
  }

  Future<void> refreshFromServer({bool force = false}) async {
    if (_closed) return;
    _syncIdentity();
    if (_userId == null) {
      error.value = 'Sign in to track your daily challenge.';
      return;
    }
    if (_refresh != null) {
      await _refresh;
      if (force) await refreshFromServer(force: true);
      return;
    }
    if (!force &&
        _lastFetch != null &&
        _now().toUtc().difference(_lastFetch!) < const Duration(seconds: 30)) {
      return;
    }
    final request = _fetch();
    _refresh = request;
    try {
      await request;
    } finally {
      _refresh = null;
    }
  }

  Future<void> _fetch() async {
    final revision = _revision;
    final userId = _userId;
    isLoading.value = true;
    try {
      final data = await _database.fetchDailyChallengeProgress();
      _syncIdentity();
      if (_revision != revision || _userId != userId) return;
      await _apply(data, fromRun: false);
      _lastFetch = _now().toUtc();
      error.value = null;
    } catch (exception) {
      debugPrint('Daily challenge refresh failed: ${exception.runtimeType}');
      if (_revision == revision) {
        error.value =
            'Could not load today’s challenge. Check your connection and retry.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> recordCompletedRun({
    required String runId,
    required Duration duration,
    required double distanceMeters,
    required bool isSimulation,
  }) async {
    if (isSimulation) return false;
    _syncIdentity();
    if (_userId == null) {
      error.value = 'Sign in to save daily challenge progress.';
      return false;
    }
    if (runId.isEmpty ||
        duration.isNegative ||
        !distanceMeters.isFinite ||
        distanceMeters < 0) {
      throw ArgumentError(
        'A completed run needs valid identity, duration and distance.',
      );
    }
    // Do not blindly replay a failed non-idempotent server insertion.
    if (!_recordedRuns.add(runId)) return false;
    if (_recordedRuns.length > 32) _recordedRuns.remove(_recordedRuns.first);
    final userId = _userId;
    final revision = ++_revision;
    try {
      final result = await _database.createRunAndMaybeAward(
        durationMinutes: duration.inMinutes,
        distanceMeters: distanceMeters,
      );
      _syncIdentity();
      if (_revision != revision || _userId != userId) return false;
      await _apply(result, fromRun: true);
      error.value = null;
      _lastFetch = null;
      return result?['awarded'] == true;
    } catch (exception) {
      debugPrint('Daily challenge run sync failed: ${exception.runtimeType}');
      if (_revision == revision) {
        error.value =
            'Your run is saved on this device, but daily challenge sync failed. '
            'Refresh to check the server result.';
      }
      return false;
    }
  }

  Future<void> _apply(
    Map<String, dynamic>? data, {
    required bool fromRun,
  }) async {
    final distance = data?['total_distance_today'];
    final minutes = data?['total_minutes_today'];
    final coins = data?['coins'];
    final completion = data?[fromRun ? 'awarded' : 'completed'];
    if (distance is! num ||
        !distance.toDouble().isFinite ||
        distance < 0 ||
        minutes is! num ||
        minutes < 0 ||
        coins is! num ||
        coins < 0 ||
        completion is! bool) {
      throw const FormatException('Invalid daily challenge progress');
    }
    distanceMetersToday.value = distance.toDouble();
    durationMinutesToday.value = minutes.toInt();
    isCompletedToday.value = fromRun
        ? isCompletedToday.value || completion
        : completion;
    final timestamp = data?['completed_at'];
    completedAt.value = timestamp is String
        ? DateTime.tryParse(timestamp)
        : null;
    if (_saveCoins != null) {
      await _saveCoins(coins.toInt());
    } else if (Get.isRegistered<UserPreferencesService>()) {
      await Get.find<UserPreferencesService>().applyServerCoins(coins.toInt());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshFromServer(force: true));
    }
  }

  String friendlyDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void onClose() {
    _closed = true;
    _revision++;
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
