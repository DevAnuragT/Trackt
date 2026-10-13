import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/territory/territory_model.dart';
import '../../../services/run_history_service.dart';

class RecentTerritoriesSection extends StatelessWidget {
  final TerritoryHistoryService history;
  final String? currentUserId;
  final Future<void> Function(Territory) onSelect;

  const RecentTerritoriesSection({
    super.key,
    required this.history,
    required this.currentUserId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final territories = history.recentTerritories.toList();
      final loading = history.isLoading.value;
      final failed = history.hasError.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent territories',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your latest claims. Tap a territory to view it on the map.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (loading) ...[
            const LinearProgressIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surfaceVariant,
            ),
            const SizedBox(height: 12),
          ],
          if (failed) ...[
            const Text(
              'Could not refresh territories. Check your connection.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            TextButton(
              onPressed: loading ? null : history.refreshTerritories,
              child: const Text('Retry'),
            ),
          ] else if (territories.isEmpty && !loading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No territories yet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Complete a loop to make your first claim.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          for (final territory in territories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _card(context, territory),
            ),
        ],
      );
    });
  }

  Widget _card(BuildContext context, Territory territory) {
    final status = currentUserId == null
        ? 'Ownership unavailable'
        : territory.ownerId == currentUserId
        ? 'Owned territory'
        : 'No longer owned';
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onSelect(territory),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.map_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TerritoryHistoryService.displayArea(territory.area),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      history.formatDate(territory.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
