import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/power_up_service.dart';
import '../../services/user_preferences_service.dart';

/// Gamified Power-Up Shop: runners spend earned $TRACKT on timed boosts and
/// cosmetics. Replaces the former "Coming Soon" placeholder.
class StoreView extends StatelessWidget {
  const StoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final hasShop = Get.isRegistered<PowerUpService>();
    return Scaffold(
      backgroundColor: const Color(0xFF141124),
      appBar: AppBar(
        title: const Text('Power-Up Shop'),
        backgroundColor: const Color(0xFF141124),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [if (hasShop) _balanceChip()],
      ),
      body: hasShop
          ? _buildShop()
          : const Center(
              child: Text('Shop unavailable', style: TextStyle(color: Colors.white70)),
            ),
    );
  }

  Widget _balanceChip() {
    final prefs = Get.find<UserPreferencesService>();
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8338EC).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF8338EC).withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.monetization_on, color: Color(0xFFFFBE0B), size: 16),
              const SizedBox(width: 6),
              Obx(() => Text(
                    '${prefs.userCoins.value} \$TRACKT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShop() {
    final shop = Get.find<PowerUpService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          'Spend \$TRACKT to dominate the map',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Boosts earned by conquering territory. Run more, earn more.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...PowerUpService.catalog.map((item) => _PowerUpCard(item: item, shop: shop)),
      ],
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final PowerUpItem item;
  final PowerUpService shop;

  const _PowerUpCard({required this.item, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch the reactive map so the card rebuilds on purchase.
      shop.ownedUntil.length;
      final active = shop.isActive(item.id);
      final remaining = shop.remaining(item.id);
      final permanent = item.duration == null;

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1733),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? const Color(0xFF00F5D4).withValues(alpha: 0.7)
                : const Color(0xFF8338EC).withValues(alpha: 0.35),
            width: 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        permanent ? 'Permanent unlock' : 'Lasts ${_fmt(item.duration!)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F5D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      permanent
                          ? 'OWNED'
                          : (remaining != null ? _fmt(remaining) + ' left' : 'ACTIVE'),
                      style: const TextStyle(
                        color: Color(0xFF00F5D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: (permanent && active) ? null : () => _buy(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8338EC),
                  disabledBackgroundColor: const Color(0xFF2A2440),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  (permanent && active)
                      ? 'Owned'
                      : 'Buy • ${item.cost} \$TRACKT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _buy(BuildContext context) async {
    final result = await shop.purchase(item);
    switch (result) {
      case PurchaseResult.success:
        Get.snackbar(
          '${item.emoji} ${item.title} activated!',
          item.duration == null
              ? 'Permanent unlock applied.'
              : 'Active for ${_fmt(item.duration!)}.',
          backgroundColor: const Color(0xFF8338EC),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        break;
      case PurchaseResult.insufficientFunds:
        Get.snackbar(
          'Not enough \$TRACKT',
          'Conquer more territory to earn ${item.cost} \$TRACKT.',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        break;
      case PurchaseResult.alreadyActive:
        Get.snackbar('Already owned', 'You already own ${item.title}.',
            backgroundColor: const Color(0xFF2A2440), colorText: Colors.white);
        break;
      case PurchaseResult.error:
        Get.snackbar('Purchase failed', 'Please try again.',
            backgroundColor: Colors.redAccent, colorText: Colors.white);
        break;
    }
  }

  String _fmt(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
