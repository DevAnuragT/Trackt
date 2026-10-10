import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_preferences_service.dart';

/// Catalog entry for a purchasable in-game power-up.
class PowerUpItem {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int cost; // in \$TRACKT
  final Duration? duration; // null => permanent (e.g. cosmetic)

  const PowerUpItem({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.cost,
    this.duration,
  });
}

/// Outcome of a purchase attempt.
enum PurchaseResult { success, insufficientFunds, alreadyActive, error }

/// Gamified power-up shop economy: runners spend earned \$TRACKT on timed and
/// cosmetic boosts. Ownership + expiry persisted locally so purchases survive
/// restarts. Coins are debited through [UserPreferencesService].
class PowerUpService extends GetxService {
  static const String _ownedKey = 'powerup_owned_until'; // "id:epochMs" csv
  static const int permanentSentinel = -1;

  static const List<PowerUpItem> catalog = [
    PowerUpItem(
      id: 'shield',
      title: 'Territory Shield',
      description: 'Protect your territories from rival theft for 24 hours.',
      emoji: '🛡️',
      cost: 250,
      duration: Duration(hours: 24),
    ),
    PowerUpItem(
      id: 'speed',
      title: 'Speed Multiplier',
      description: 'Double \$TRACKT rewards on high-cadence runs for 1 hour.',
      emoji: '⚡',
      cost: 150,
      duration: Duration(hours: 1),
    ),
    PowerUpItem(
      id: 'flag',
      title: 'Custom Flag / Banner',
      description: 'Unlock a custom color and crest for conquered territory.',
      emoji: '🎨',
      cost: 500,
      duration: null, // permanent cosmetic
    ),
  ];

  /// id -> expiry epoch millis (or [permanentSentinel] for permanent unlocks).
  final RxMap<String, int> ownedUntil = <String, int>{}.obs;

  late SharedPreferences _prefs;

  Future<PowerUpService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    return this;
  }

  void _load() {
    ownedUntil.clear();
    final raw = _prefs.getStringList(_ownedKey) ?? const [];
    for (final entry in raw) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final ms = int.tryParse(parts[1]);
        if (ms != null) ownedUntil[parts[0]] = ms;
      }
    }
  }

  Future<void> _persist() async {
    final list = ownedUntil.entries.map((e) => '${e.key}:${e.value}').toList();
    await _prefs.setStringList(_ownedKey, list);
  }

  PowerUpItem? itemById(String id) {
    for (final i in catalog) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// True if a timed power-up is currently active, or a permanent one is owned.
  bool isActive(String id) {
    final until = ownedUntil[id];
    if (until == null) return false;
    if (until == permanentSentinel) return true;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Remaining time for a timed power-up, or null if inactive/permanent.
  Duration? remaining(String id) {
    final until = ownedUntil[id];
    if (until == null || until == permanentSentinel) return null;
    final ms = until - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : null;
  }

  /// Attempt to buy [item], debiting \$TRACKT via [UserPreferencesService].
  Future<PurchaseResult> purchase(PowerUpItem item) async {
    try {
      // Permanent items can only be bought once.
      if (item.duration == null && isActive(item.id)) {
        return PurchaseResult.alreadyActive;
      }

      if (!Get.isRegistered<UserPreferencesService>()) {
        return PurchaseResult.error;
      }
      final prefs = Get.find<UserPreferencesService>();

      final paid = await prefs.spendUserCoins(item.cost);
      if (!paid) return PurchaseResult.insufficientFunds;

      if (item.duration == null) {
        ownedUntil[item.id] = permanentSentinel;
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Stack onto remaining time if already active.
        final base = isActive(item.id) ? (ownedUntil[item.id] ?? now) : now;
        ownedUntil[item.id] = base + item.duration!.inMilliseconds;
      }
      ownedUntil.refresh();
      await _persist();
      return PurchaseResult.success;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Power-up purchase error: $e');
      return PurchaseResult.error;
    }
  }
}
