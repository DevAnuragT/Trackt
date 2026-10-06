import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum PerformanceLevel {
  low,
  medium,
  high,
  ultra
}

enum OptimizationStrategy {
  batteryLife,
  performance,
  balanced,
  custom
}

class PerformanceMetrics {
  final double frameRate;
  final int memoryUsageMB;
  final double cpuUsage;
  final double batteryLevel;
  final int territoryCount;
  final int mapLayerCount;
  final DateTime timestamp;

  PerformanceMetrics({
    required this.frameRate,
    required this.memoryUsageMB,
    required this.cpuUsage,
    required this.batteryLevel,
    required this.territoryCount,
    required this.mapLayerCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'frame_rate': frameRate,
    'memory_usage_mb': memoryUsageMB,
    'cpu_usage': cpuUsage,
    'battery_level': batteryLevel,
    'territory_count': territoryCount,
    'map_layer_count': mapLayerCount,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

class PerformanceSettings {
  final PerformanceLevel level;
  final bool enableBatchedUpdates;
  final bool enableLevelOfDetail;
  final bool enableViewportCulling;
  final bool enableTextureCompression;
  final int maxSimultaneousAnimations;
  final int territoryUpdateInterval;
  final int maxVisibleTerritories;
  final double renderScale;

  PerformanceSettings({
    required this.level,
    required this.enableBatchedUpdates,
    required this.enableLevelOfDetail,
    required this.enableViewportCulling,
    required this.enableTextureCompression,
    required this.maxSimultaneousAnimations,
    required this.territoryUpdateInterval,
    required this.maxVisibleTerritories,
    required this.renderScale,
  });

  static PerformanceSettings forLevel(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.low:
        return PerformanceSettings(
          level: level,
          enableBatchedUpdates: true,
          enableLevelOfDetail: true,
          enableViewportCulling: true,
          enableTextureCompression: true,
          maxSimultaneousAnimations: 2,
          territoryUpdateInterval: 60000, // 1 minute
          maxVisibleTerritories: 20,
          renderScale: 0.7,
        );
      case PerformanceLevel.medium:
        return PerformanceSettings(
          level: level,
          enableBatchedUpdates: true,
          enableLevelOfDetail: true,
          enableViewportCulling: true,
          enableTextureCompression: false,
          maxSimultaneousAnimations: 4,
          territoryUpdateInterval: 30000, // 30 seconds
          maxVisibleTerritories: 50,
          renderScale: 0.85,
        );
      case PerformanceLevel.high:
        return PerformanceSettings(
          level: level,
          enableBatchedUpdates: true,
          enableLevelOfDetail: false,
          enableViewportCulling: true,
          enableTextureCompression: false,
          maxSimultaneousAnimations: 8,
          territoryUpdateInterval: 15000, // 15 seconds
          maxVisibleTerritories: 100,
          renderScale: 1.0,
        );
      case PerformanceLevel.ultra:
        return PerformanceSettings(
          level: level,
          enableBatchedUpdates: false,
          enableLevelOfDetail: false,
          enableViewportCulling: false,
          enableTextureCompression: false,
          maxSimultaneousAnimations: 16,
          territoryUpdateInterval: 5000, // 5 seconds
          maxVisibleTerritories: 200,
          renderScale: 1.0,
        );
    }
  }
}

class PerformanceOptimizationController extends GetxController {
  // Observable state
  final Rx<PerformanceSettings> currentSettings = PerformanceSettings.forLevel(PerformanceLevel.medium).obs;
  final Rx<OptimizationStrategy> strategy = OptimizationStrategy.balanced.obs;
  final RxList<PerformanceMetrics> metricsHistory = <PerformanceMetrics>[].obs;
  final Rx<PerformanceMetrics?> currentMetrics = Rx<PerformanceMetrics?>(null);
  final RxBool autoOptimizationEnabled = true.obs;
  final RxBool debugModeEnabled = false.obs;

  // Performance monitoring
  final RxDouble averageFrameRate = 60.0.obs;
  final RxDouble memoryPressure = 0.0.obs;
  final RxBool isThrottling = false.obs;
  final RxInt droppedFrames = 0.obs;
  final RxBool lowBattery = false.obs;

  // Optimization states
  final RxBool isCullingEnabled = true.obs;
  final RxBool isLODEnabled = true.obs;
  final RxBool isBatchingEnabled = true.obs;
  final RxInt activeAnimations = 0.obs;
  final RxInt visibleTerritories = 0.obs;

  Timer? _metricsTimer;
  Timer? _optimizationTimer;

  @override
  void onInit() {
    super.onInit();
    _initializePerformanceSettings();
    _startPerformanceMonitoring();
    _startAutoOptimization();
  }

  @override
  void onClose() {
    _metricsTimer?.cancel();
    _optimizationTimer?.cancel();
    super.onClose();
  }

  /// Initialize performance settings based on device capabilities
  void _initializePerformanceSettings() {
    // Auto-detect device performance level
    final deviceLevel = _detectDevicePerformanceLevel();
    _applyPerformanceLevel(deviceLevel);
    
    print('🚀 Performance optimization initialized at ${deviceLevel.name} level');
  }

  /// Detect device performance level
  PerformanceLevel _detectDevicePerformanceLevel() {
    // In a real implementation, this would check:
    // - Device specs (RAM, CPU cores, GPU)
    // - Platform (iOS/Android/Web)
    // - Available memory
    // - Battery status
    
    // For demo, use medium as default
    return PerformanceLevel.medium;
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _collectPerformanceMetrics(),
    );
  }

  /// Collect current performance metrics
  Future<void> _collectPerformanceMetrics() async {
    try {
      final metrics = PerformanceMetrics(
        frameRate: _getCurrentFrameRate(),
        memoryUsageMB: await _getMemoryUsage(),
        cpuUsage: _getCPUUsage(),
        batteryLevel: await _getBatteryLevel(),
        territoryCount: visibleTerritories.value,
        mapLayerCount: _getMapLayerCount(),
        timestamp: DateTime.now(),
      );

      currentMetrics.value = metrics;
      metricsHistory.add(metrics);
      
      // Keep only last 100 metrics
      if (metricsHistory.length > 100) {
        metricsHistory.removeAt(0);
      }

      _updatePerformanceIndicators(metrics);

      if (debugModeEnabled.value) {
        print('📊 FPS: ${metrics.frameRate.toStringAsFixed(1)}, '
              'Memory: ${metrics.memoryUsageMB}MB, '
              'CPU: ${metrics.cpuUsage.toStringAsFixed(1)}%');
      }
      
    } catch (e) {
      print('❌ Error collecting performance metrics: $e');
    }
  }

  /// Get current frame rate
  double _getCurrentFrameRate() {
    // In production, this would use WidgetsBinding.instance.addTimingsCallback
    // For now, simulate based on performance level
    final random = math.Random();
    switch (currentSettings.value.level) {
      case PerformanceLevel.low:
        return 25 + random.nextDouble() * 10; // 25-35 FPS
      case PerformanceLevel.medium:
        return 40 + random.nextDouble() * 15; // 40-55 FPS
      case PerformanceLevel.high:
        return 55 + random.nextDouble() * 10; // 55-65 FPS
      case PerformanceLevel.ultra:
        return 58 + random.nextDouble() * 7; // 58-65 FPS
    }
  }

  /// Get memory usage in MB
  Future<int> _getMemoryUsage() async {
    // Simulate memory usage based on territories and settings
    final baseMemory = 120; // Base app memory
    final territoryMemory = visibleTerritories.value * 2; // 2MB per territory
    final settingsMultiplier = currentSettings.value.renderScale;
    
    return (baseMemory + territoryMemory * settingsMultiplier).round();
  }

  /// Get CPU usage percentage
  double _getCPUUsage() {
    // Simulate CPU usage
    final random = math.Random();
    final baseUsage = 15.0; // Base CPU usage
    final territoryUsage = visibleTerritories.value * 0.5;
    final animationUsage = activeAnimations.value * 2.0;
    
    return math.min(baseUsage + territoryUsage + animationUsage + random.nextDouble() * 10, 100.0);
  }

  /// Get battery level
  Future<double> _getBatteryLevel() async {
    // In production, would use battery_plus package
    // For now, simulate declining battery
    return math.max(20.0, 100.0 - DateTime.now().hour * 3);
  }

  /// Get map layer count
  int _getMapLayerCount() {
    // Simulate map layers based on settings
    int layers = 3; // Base layers (map, user location, UI)
    layers += visibleTerritories.value > 0 ? 1 : 0; // Territory layer
    layers += currentSettings.value.enableLevelOfDetail ? 1 : 0; // LOD layer
    return layers;
  }

  /// Update performance indicators
  void _updatePerformanceIndicators(PerformanceMetrics metrics) {
    averageFrameRate.value = metricsHistory.isEmpty 
        ? metrics.frameRate 
        : metricsHistory.map((m) => m.frameRate).reduce((a, b) => a + b) / metricsHistory.length;

    memoryPressure.value = metrics.memoryUsageMB / 1024.0; // Convert to GB
    isThrottling.value = metrics.frameRate < 30;
    lowBattery.value = metrics.batteryLevel < 20;
    
    if (metrics.frameRate < averageFrameRate.value - 10) {
      droppedFrames.value++;
    }
  }

  /// Start auto optimization
  void _startAutoOptimization() {
    _optimizationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performAutoOptimization(),
    );
  }

  /// Perform automatic optimization
  void _performAutoOptimization() {
    if (!autoOptimizationEnabled.value || currentMetrics.value == null) return;

    final metrics = currentMetrics.value!;
    
    // Check if optimization is needed
    if (_shouldOptimize(metrics)) {
      _optimizeBasedOnMetrics(metrics);
    }
  }

  /// Check if optimization is needed
  bool _shouldOptimize(PerformanceMetrics metrics) {
    return metrics.frameRate < 25 || // Poor frame rate
           metrics.memoryUsageMB > 500 || // High memory usage
           metrics.cpuUsage > 80 || // High CPU usage
           lowBattery.value; // Low battery
  }

  /// Optimize based on current metrics
  void _optimizeBasedOnMetrics(PerformanceMetrics metrics) {
    PerformanceLevel newLevel = currentSettings.value.level;

    // Determine optimization strategy
    if (lowBattery.value) {
      // Battery optimization
      newLevel = PerformanceLevel.low;
      _showOptimizationNotification('Battery Optimization', 'Reduced performance to save battery');
    } else if (metrics.frameRate < 20) {
      // Performance critical
      newLevel = _downgradePerfLevel(currentSettings.value.level);
      _showOptimizationNotification('Performance Optimization', 'Reduced settings for better frame rate');
    } else if (metrics.memoryUsageMB > 500) {
      // Memory optimization
      _optimizeMemoryUsage();
      _showOptimizationNotification('Memory Optimization', 'Cleared unused resources');
    }

    if (newLevel != currentSettings.value.level) {
      _applyPerformanceLevel(newLevel);
    }
  }

  /// Downgrade performance level
  PerformanceLevel _downgradePerfLevel(PerformanceLevel current) {
    switch (current) {
      case PerformanceLevel.ultra:
        return PerformanceLevel.high;
      case PerformanceLevel.high:
        return PerformanceLevel.medium;
      case PerformanceLevel.medium:
        return PerformanceLevel.low;
      case PerformanceLevel.low:
        return PerformanceLevel.low; // Already at lowest
    }
  }

  /// Optimize memory usage
  void _optimizeMemoryUsage() {
    // Trigger garbage collection
    if (kDebugMode) {
      print('🧹 Triggering memory optimization...');
    }
    
    // In production, this would:
    // - Clear unused territory data
    // - Compress textures
    // - Reduce cache sizes
    // - Unload off-screen resources
  }

  /// Show optimization notification
  void _showOptimizationNotification(String title, String message) {
    if (!debugModeEnabled.value) return;
    
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.orange.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.tune, color: Colors.white),
    );
  }

  /// Apply performance level
  void _applyPerformanceLevel(PerformanceLevel level) {
    currentSettings.value = PerformanceSettings.forLevel(level);
    _updateOptimizationStates();
    
    print('⚡ Applied ${level.name} performance settings');
  }

  /// Update optimization states
  void _updateOptimizationStates() {
    final settings = currentSettings.value;
    isCullingEnabled.value = settings.enableViewportCulling;
    isLODEnabled.value = settings.enableLevelOfDetail;
    isBatchingEnabled.value = settings.enableBatchedUpdates;
  }

  /// Manual performance level change
  void setPerformanceLevel(PerformanceLevel level) {
    _applyPerformanceLevel(level);
    
    Get.snackbar(
      'Performance Settings',
      'Applied ${level.name} performance level',
      backgroundColor: Colors.blue.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Set optimization strategy
  void setOptimizationStrategy(OptimizationStrategy newStrategy) {
    strategy.value = newStrategy;
    
    // Apply strategy-specific settings
    switch (newStrategy) {
      case OptimizationStrategy.batteryLife:
        _applyPerformanceLevel(PerformanceLevel.low);
        autoOptimizationEnabled.value = true;
        break;
      case OptimizationStrategy.performance:
        _applyPerformanceLevel(PerformanceLevel.ultra);
        autoOptimizationEnabled.value = false;
        break;
      case OptimizationStrategy.balanced:
        _applyPerformanceLevel(PerformanceLevel.medium);
        autoOptimizationEnabled.value = true;
        break;
      case OptimizationStrategy.custom:
        // Keep current settings
        break;
    }
    
    print('🎯 Set optimization strategy to ${newStrategy.name}');
  }

  /// Toggle auto optimization
  void toggleAutoOptimization(bool enabled) {
    autoOptimizationEnabled.value = enabled;
    
    if (enabled) {
      _startAutoOptimization();
    } else {
      _optimizationTimer?.cancel();
    }
  }

  /// Toggle debug mode
  void toggleDebugMode(bool enabled) {
    debugModeEnabled.value = enabled;
    
    if (enabled) {
      _showPerformanceOverlay();
    }
  }

  /// Show performance overlay
  void _showPerformanceOverlay() {
    Get.snackbar(
      'Debug Mode Enabled',
      'Performance metrics will be logged to console',
      backgroundColor: Colors.purple.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }

  /// Force optimization now
  void forceOptimization() {
    _performAutoOptimization();
    
    Get.snackbar(
      'Optimization Complete',
      'Performance has been optimized based on current conditions',
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Clear performance history
  void clearMetricsHistory() {
    metricsHistory.clear();
    droppedFrames.value = 0;
    
    Get.snackbar(
      'Metrics Cleared',
      'Performance history has been reset',
      backgroundColor: Colors.blue.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    if (metricsHistory.isEmpty) {
      return {
        'status': 'No data available',
        'avg_fps': 0.0,
        'avg_memory': 0,
        'optimization_count': 0,
      };
    }

    final avgFps = metricsHistory.map((m) => m.frameRate).reduce((a, b) => a + b) / metricsHistory.length;
    final avgMemory = metricsHistory.map((m) => m.memoryUsageMB).reduce((a, b) => a + b) / metricsHistory.length;
    
    String status = 'Excellent';
    if (avgFps < 30) {
      status = 'Poor';
    } else if (avgFps < 45) status = 'Fair';
    else if (avgFps < 55) status = 'Good';
    
    return {
      'status': status,
      'avg_fps': avgFps,
      'avg_memory': avgMemory.round(),
      'dropped_frames': droppedFrames.value,
      'current_level': currentSettings.value.level.name,
      'auto_optimization': autoOptimizationEnabled.value,
      'territories_visible': visibleTerritories.value,
    };
  }

  /// Update visible territories count (called from territory controller)
  void updateVisibleTerritories(int count) {
    visibleTerritories.value = count;
  }

  /// Update active animations count
  void updateActiveAnimations(int count) {
    activeAnimations.value = count;
  }

  /// Get recommendations for better performance
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];
    final metrics = currentMetrics.value;
    
    if (metrics == null) return recommendations;

    if (metrics.frameRate < 30) {
      recommendations.add('Consider reducing territory visibility radius');
      recommendations.add('Disable animations for better frame rate');
    }
    
    if (metrics.memoryUsageMB > 400) {
      recommendations.add('Clear app cache to free memory');
      recommendations.add('Reduce map texture quality');
    }
    
    if (lowBattery.value) {
      recommendations.add('Enable battery optimization mode');
      recommendations.add('Reduce background updates');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal - no changes needed');
    }
    
    return recommendations;
  }
}
