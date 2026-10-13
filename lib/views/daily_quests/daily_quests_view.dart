import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../services/daily_challenge_service.dart';

class DailyQuestsView extends StatefulWidget {
  const DailyQuestsView({super.key});

  @override
  State<DailyQuestsView> createState() => _DailyQuestsViewState();
}

class _DailyQuestsViewState extends State<DailyQuestsView> {
  late final DailyChallengeService _challenge;

  @override
  void initState() {
    super.initState();
    _challenge = Get.isRegistered<DailyChallengeService>()
        ? Get.find<DailyChallengeService>()
        : Get.put(DailyChallengeService());
    _challenge.refreshFromServer(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily challenge'),
        actions: [
          IconButton(
            tooltip: 'Refresh challenge',
            onPressed: () => _challenge.refreshFromServer(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _challenge.refreshFromServer(force: true),
        child: Obx(
          () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'A little movement, every day.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          _challenge.isCompletedToday.value
                              ? 'Completed today'
                              : 'Today’s goal',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '+${_challenge.rewardCoins.value} in-game coins',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Run a total of 500 m and 10 active minutes today. '
                      'Completed real runs add up, even without a territory.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _progress(
                      'Distance',
                      _challenge.distanceMetersToday.value,
                      DailyChallengeService.targetDistance,
                      'm',
                    ),
                    const SizedBox(height: 20),
                    _progress(
                      'Active time',
                      _challenge.durationMinutesToday.value.toDouble(),
                      DailyChallengeService.targetMinutes.toDouble(),
                      'min',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _challenge.isCompletedToday.value
                          ? 'Reward claimed for today. Keep running for tomorrow.'
                          : 'Finish a real run to save your progress.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (_challenge.isLoading.value) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ],
                    if (_challenge.error.value != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _challenge.error.value!,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _challenge.isLoading.value
                            ? null
                            : () => _challenge.refreshFromServer(force: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Resets at midnight UTC. Rewarded once per day. '
                'Judge Demo simulations do not count. Active minutes are recorded '
                'as whole minutes for each completed run.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(String label, double value, double target, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 6,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / target).clamp(0, 1),
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceVariant,
          ),
        ),
      ],
    );
  }
}
