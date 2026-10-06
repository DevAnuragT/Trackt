import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/territory/run_session_model.dart';

/// Simple service for storing recent 10 runs locally
/// Used for run path display on map and basic run history
class RunStorageService extends GetxService {
  static const String _recentRunsKey = 'recent_runs';
  static const int _maxRecentRuns = 10;
  static const double _minRunDistance = 200.0; // Minimum distance to save a run
  
  // Observable list of recent runs
  final RxList<RunSession> recentRuns = <RunSession>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    loadRecentRuns();
  }
  
  /// Load recent runs from local storage
  Future<void> loadRecentRuns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String? recentRunsJson = prefs.getString(_recentRunsKey);
      if (recentRunsJson != null) {
        final List<dynamic> runsList = jsonDecode(recentRunsJson);
        recentRuns.value = runsList.map((json) => RunSession.fromJson(json)).toList();
      }
      
      print('📱 Loaded ${recentRuns.length} recent runs from local storage');
    } catch (e) {
      print('❌ Error loading recent runs: $e');
    }
  }
  
  /// Save a run to recent runs (keeps only latest 10)
  Future<void> saveRun(RunSession runSession) async {
    try {
      // Check minimum distance requirement
      if (runSession.distance! < _minRunDistance) {
        print('Run not saved: Distance ${runSession.distance!.toStringAsFixed(1)}m is less than ${_minRunDistance}m');
        return;
      }

      // Add to recent runs (limited to max count)
      recentRuns.insert(0, runSession);
      if (recentRuns.length > _maxRecentRuns) {
        recentRuns.removeRange(_maxRecentRuns, recentRuns.length);
      }
      
      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      final recentRunsJson = jsonEncode(recentRuns.map((run) => run.toJson()).toList());
      await prefs.setString(_recentRunsKey, recentRunsJson);
      
      print('✅ Run saved locally: ${runSession.distance!.toStringAsFixed(1)}m');
      
      Get.showSnackbar(
        GetSnackBar(
          title: 'Run Saved',
          message: 'Your ${runSession.distance!.toStringAsFixed(1)}m run has been saved.',
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error saving run: $e');
    }
  }
  
  /// Get recent runs for display
  List<RunSession> getRecentRuns() {
    return recentRuns.toList();
  }
  
  /// Clear all recent runs
  Future<void> clearRecentRuns() async {
    try {
      recentRuns.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentRunsKey);
      
      print('🗑️ Recent runs cleared');
    } catch (e) {
      print('❌ Error clearing recent runs: $e');
    }
  }
  
  /// Format distance for display
  String formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distance.toStringAsFixed(0)} m';
    }
  }
  
  /// Format duration for display
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Format date for display
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
