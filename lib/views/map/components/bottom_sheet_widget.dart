import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/map/run_tracker_controller.dart';
import '../../../controllers/map/territory_display_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/territory/territory_model.dart';
import '../../../services/database_service.dart';
import '../../../services/location_permission_service.dart';
import '../../../services/run_history_service.dart';
import '../../run/run_page.dart';
import 'recent_territories_section.dart';

class BottomSheetController extends GetxController {
  final RxInt totalRuns = 0.obs;
  final RxBool isLoadingStats = false.obs;
  final RxnString statsError = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadUserStatistics();
  }

  Future<void> loadUserStatistics() async {
    isLoadingStats.value = true;
    try {
      final stats = await Get.find<DatabaseService>().getUserStatistics();
      if (stats == null) throw StateError('Statistics unavailable');
      final count = stats['total_runs'];
      if (count is! num) throw const FormatException('Invalid run statistics');
      totalRuns.value = count.toInt();
      statsError.value = null;
    } catch (exception) {
      debugPrint('Could not load map statistics: ${exception.runtimeType}');
      statsError.value = 'Statistics are unavailable. Pull down to refresh.';
    } finally {
      isLoadingStats.value = false;
    }
  }

  Future<void> refreshStatistics() => loadUserStatistics();

  Future<void> forceRefreshStatistics() async {
    final database = Get.find<DatabaseService>();
    final user = database.currentUserId;
    if (user != null) await database.recomputeUserStatistics(user);
    await loadUserStatistics();
  }
}

class TerritoryBottomSheet extends StatefulWidget {
  const TerritoryBottomSheet({super.key});

  static void refresh() {
    if (Get.isRegistered<TerritoryHistoryService>()) {
      Get.find<TerritoryHistoryService>().recentTerritories.refresh();
    }
    if (Get.isRegistered<BottomSheetController>()) {
      Get.find<BottomSheetController>().refreshStatistics();
    }
  }

  @override
  State<TerritoryBottomSheet> createState() => _TerritoryBottomSheetState();
}

class _TerritoryBottomSheetState extends State<TerritoryBottomSheet> {
  final _sheet = DraggableScrollableController();

  Future<void> _focusTerritory(Territory territory) async {
    if (!Get.isRegistered<TerritoryDisplayController>()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The map is not ready. Try again shortly.'),
        ),
      );
      return;
    }
    try {
      await Get.find<TerritoryDisplayController>().flyToTerritory(territory);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${TerritoryHistoryService.displayArea(territory.area)} territory focused',
          ),
        ),
      );
      if (_sheet.isAttached) {
        await _sheet.animateTo(
          0.10,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (exception) {
      debugPrint('Recent territory focus failed: ${exception.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not focus the map. Try again shortly.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BottomSheetController>(
      init: BottomSheetController(),
      builder: (stats) => DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: 0.26,
        minChildSize: 0.10,
        maxChildSize: 0.75,
        builder: (context, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SingleChildScrollView(
            controller: scroll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'My territories',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _stats(stats),
                  const SizedBox(height: 20),
                  _startRun(),
                  const SizedBox(height: 28),
                  if (Get.isRegistered<TerritoryHistoryService>())
                    RecentTerritoriesSection(
                      history: Get.find<TerritoryHistoryService>(),
                      currentUserId: Get.isRegistered<DatabaseService>()
                          ? Get.find<DatabaseService>().currentUserId
                          : null,
                      onSelect: _focusTerritory,
                    )
                  else
                    const Text(
                      'Territory history is unavailable.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stats(BottomSheetController stats) => Obx(() {
    final history = Get.isRegistered<TerritoryHistoryService>()
        ? Get.find<TerritoryHistoryService>()
        : null;
    final area = history?.allTerritories.fold<double>(
      0,
      (sum, territory) => sum + territory.area,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 36,
            runSpacing: 16,
            children: [
              _stat(
                'Total area',
                area == null
                    ? 'Unavailable'
                    : TerritoryHistoryService.displayArea(area),
              ),
              _stat(
                'Completed runs',
                stats.isLoadingStats.value
                    ? 'Loading...'
                    : '${stats.totalRuns.value}',
              ),
            ],
          ),
          if (stats.statsError.value != null) ...[
            const SizedBox(height: 10),
            Text(
              stats.statsError.value!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  });

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ],
  );

  Widget _startRun() {
    final tracker = Get.isRegistered<RunTrackerController>()
        ? Get.find<RunTrackerController>()
        : null;
    Widget button(bool running) => SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: running
            ? null
            : () async {
                if (Get.isRegistered<LocationPermissionService>()) {
                  await Get.find<LocationPermissionService>()
                      .maybeShowAllowAllTimeDialogAndOpenSettings();
                }
                if (mounted) {
                  Get.to(() => const RunPageAutoStart(autoStart: true));
                }
              },
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: Text(running ? 'Run in progress' : 'Start run'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return tracker == null
        ? button(false)
        : Obx(() => button(tracker.isRunning.value));
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }
}
