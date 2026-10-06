import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/user_preferences_service.dart';

class DailyQuestsView extends StatelessWidget {
  const DailyQuestsView({super.key});

  DailyChallengeService _ensureService() {
    if (!Get.isRegistered<DailyChallengeService>()) {
      Get.put(DailyChallengeService());
    }
    final svc = Get.find<DailyChallengeService>();
    // Fire and forget refresh (won't spam due to internal cache)
    svc.refreshFromServer();
    return svc;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child:
    Scaffold(
      backgroundColor: Colors.black87,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
    child: Column(
          children: [
      // Header (reduced spacing & font size)
      Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 32,
                  color: Colors.amber[400],
                ),
                const SizedBox(width: 12),
        const Text('Daily Quests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
      const SizedBox(height: 20),
            // Daily Challenge Card
            Builder(
              builder: (context) {
                final svc = _ensureService();
                final prefs = Get.isRegistered<UserPreferencesService>() ? Get.find<UserPreferencesService>() : null;
                return Obx(() {
                  final coins = prefs?.userCoins.value ?? 0;
                  final completed = svc.isCompletedToday.value;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: completed
                            ? [Colors.green[600]!, Colors.green[400]!]
                            : [Colors.indigo[700]!, Colors.indigo[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              completed ? Icons.check_circle : Icons.flag,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Daily Challenge',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  const Text('100', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Complete a run of at least 10 min and 500 m today to earn 100 coins.',
                          style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                        const SizedBox(height: 12),
                        _ProgressBar(
                          label: 'Distance',
                          value: (svc.distanceMetersToday.value).clamp(0, DailyChallengeService.targetDistance),
                          max: DailyChallengeService.targetDistance,
                          unit: 'm',
                          completedColor: Colors.greenAccent,
                        ),
                        const SizedBox(height: 8),
                        _ProgressBar(
                          label: 'Duration',
                          value: (svc.durationMinutesToday.value.toDouble()).clamp(0, DailyChallengeService.targetMinutes.toDouble()),
                          max: DailyChallengeService.targetMinutes.toDouble(),
                          unit: 'min',
                          completedColor: Colors.greenAccent,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                completed ? 'Completed today!' : 'Not completed yet',
                                style: TextStyle(
                                  color: completed ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'Balance: $coins',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        if (completed && svc.completedAt.value != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Completed at ${svc.friendlyDate(svc.completedAt.value)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ]
                      ],
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 30),
            // Additional info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[400],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete today\'s challenge once per day. Resets at UTC midnight.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color completedColor;
  const _ProgressBar({
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    required this.completedColor,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final done = fraction >= 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(label == 'Distance' ? 0 : 0)}/${max.toStringAsFixed(0)} $unit',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.18),
            valueColor: AlwaysStoppedAnimation<Color>(done ? completedColor : Colors.amber),
          ),
        ),
      ],
    );
  }
}
