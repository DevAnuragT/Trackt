import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/simulation_service.dart';

class AiRecapCard extends StatefulWidget {
  final SimulationResult result;

  const AiRecapCard({super.key, required this.result});

  @override
  State<AiRecapCard> createState() => _AiRecapCardState();
}

class _AiRecapCardState extends State<AiRecapCard> {
  Future<AiRecap>? _recap;
  String? _unavailable;
  bool _disabled = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AiService>() && !Get.find<AiService>().enabled) {
      _disabled = true;
      return;
    }
    if (!Get.isRegistered<AiService>() || !Get.find<AiService>().isConfigured) {
      _unavailable = 'AI recaps are not configured.';
      return;
    }
    final service = Get.find<AiService>();
    if (!service.isSignedIn) {
      _unavailable = 'Sign in for a KIMI conquest recap.';
      return;
    }
    _recap = service.conquestRecap(
      city: widget.result.city,
      areaSqMeters: widget.result.areaM2,
      distanceMeters: widget.result.distanceMeters,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_disabled) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<AiRecap>(
        future: _recap,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final text =
              _unavailable ??
              (snapshot.hasError
                  ? snapshot.error.toString()
                  : data?.message ?? 'Generating your conquest recap...');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data == null ? 'Conquest recap' : 'KIMI recap',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
