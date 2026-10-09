import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/simulation_service.dart';

class SimulationSheet extends StatefulWidget {
  const SimulationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SimulationSheet(),
    );
  }

  @override
  State<SimulationSheet> createState() => _SimulationSheetState();
}

class _SimulationSheetState extends State<SimulationSheet> {
  final SimulationService simService = Get.find<SimulationService>();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141124),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: const Color(0xFF8338EC).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8338EC).withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8338EC).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF8338EC),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.science,
                          color: Color(0xFF00F5D4),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Judge Simulation Lab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Metropolis Evaluation Engine',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F5D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00F5D4).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'MONAD TESTNET',
                      style: TextStyle(
                        color: Color(0xFF00F5D4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Explanation note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1936),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white12,
                    width: 1,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF3A86FF), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulates realistic organic GPS run loops on Mapbox with real-time path drawing, sub-second loop closure detection, and territory conquest.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Presets Section
              const Text(
                'SELECT TEST CIRCUIT',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),

              Obx(() => Column(
                children: SimulationService.presets.map((preset) {
                  final isSelected = simService.selectedPreset.value == preset.preset;
                  return InkWell(
                    onTap: () {
                      simService.selectedPreset.value = preset.preset;
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8338EC).withValues(alpha: 0.22)
                            : const Color(0xFF1C1830),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8338EC)
                              : Colors.white10,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8338EC)
                                  : const Color(0xFF282342),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              preset.icon,
                              color: isSelected ? Colors.white : Colors.white70,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      preset.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${preset.city})',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  preset.description,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00F5D4),
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )),
              const SizedBox(height: 10),

              // Speed selector
              const Text(
                'SIMULATION SPEED',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),

              Obx(() => Row(
                children: [
                  Expanded(
                    child: _buildSpeedChip(
                      speed: SimulationSpeed.turbo,
                      title: '⚡ Turbo',
                      subtitle: '~5s loop',
                      isSelected: simService.selectedSpeed.value == SimulationSpeed.turbo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpeedChip(
                      speed: SimulationSpeed.demo,
                      title: '🎬 Demo',
                      subtitle: '~14s loop',
                      isSelected: simService.selectedSpeed.value == SimulationSpeed.demo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpeedChip(
                      speed: SimulationSpeed.natural,
                      title: '🏃 Natural',
                      subtitle: '~30s loop',
                      isSelected: simService.selectedSpeed.value == SimulationSpeed.natural,
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 18),

              // Launch button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // Dismiss bottom sheet
                    await simService.launchSimulation(context: context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8338EC),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFF8338EC).withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Launch Simulated Run',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip({
    required SimulationSpeed speed,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        simService.selectedSpeed.value = speed;
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8338EC).withValues(alpha: 0.3)
              : const Color(0xFF1E1936),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8338EC) : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00F5D4) : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
