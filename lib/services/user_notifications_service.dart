import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/territory/steal_event_model.dart';
import 'database_service.dart';

class UserNotificationsService extends GetxService {
  final DatabaseService _databaseService = DatabaseService();

  final RxList<StealEvent> events = <StealEvent>[].obs;
  final RxBool hasUnread = false.obs;
  final RxBool isLoading = false.obs;

  // Track read state locally by event id
  final RxSet<String> readIds = <String>{}.obs;
  // Track deleted/hidden notifications locally
  final RxSet<String> hiddenIds = <String>{}.obs;

  Future<UserNotificationsService> init() async {
    await _loadReadIds();
    await _loadHiddenIds();
    await refresh();
    return this;
  }

  Future<void> refresh() async {
    try {
      isLoading.value = true;
      final fetched = await _databaseService.getStealEventsForCurrentUser();
      
      // Clear local hiddenIds since we're now using database deletion tracking
      // This prevents the bug where switching accounts shows filtered notifications
      hiddenIds.clear();
      _saveHiddenIds();
      
      // No need to filter locally since database handles deletion
      events.assignAll(fetched);
      _recomputeUnread();
    } finally {
      isLoading.value = false;
    }
  }

  void markAsRead(String eventId) async {
    readIds.add(eventId);
    _recomputeUnread();
    _saveReadIds();
    
    // Update database to mark notification as read
    try {
      await _databaseService.markStealNotificationAsRead(eventId);
    } catch (e) {
      print('⚠️ Failed to update read status in database: $e');
    }
  }

  void markAllAsRead() {
    for (final e in events) {
      readIds.add(e.id);
    }
    _recomputeUnread();
    _saveReadIds();
  }

  void deleteEvent(String eventId) async {
    events.removeWhere((e) => e.id == eventId);
    readIds.remove(eventId);
    _recomputeUnread();
    _saveReadIds();
    
    // Update database to mark notification as deleted
    // No need to maintain local hiddenIds since database handles deletion
    try {
      await _databaseService.markStealNotificationAsDeleted(eventId);
    } catch (e) {
      print('⚠️ Failed to update delete status in database: $e');
    }
  }

  void deleteAll() {
    // Mark all current events as deleted in database
    for (final e in events) {
      try {
        _databaseService.markStealNotificationAsDeleted(e.id);
      } catch (e) {
        print('⚠️ Failed to mark notification as deleted: $e');
      }
    }
    
    events.clear();
    readIds.clear();
    _recomputeUnread();
    _saveReadIds();
    
    // Clear local hiddenIds since we're using database deletion
    hiddenIds.clear();
    _saveHiddenIds();
  }

  void _recomputeUnread() {
    hasUnread.value = events.any((e) => !readIds.contains(e.id));
  }

  /// Clear local storage when switching users to prevent notification mixing
  void clearLocalStorage() {
    hiddenIds.clear();
    readIds.clear();
    events.clear();
    hasUnread.value = false;
    _saveHiddenIds();
    _saveReadIds();
  }

  static const _readIdsKey = 'notification_read_ids';
  static const _hiddenIdsKey = 'notification_hidden_ids';
  Future<void> _saveReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readIdsKey, readIds.toList());
    } catch (_) {}
  }

  Future<void> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readIdsKey) ?? [];
      readIds.addAll(list);
    } catch (_) {}
  }

  Future<void> _saveHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenIdsKey, hiddenIds.toList());
    } catch (_) {}
  }

  Future<void> _loadHiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_hiddenIdsKey) ?? [];
      hiddenIds.addAll(list);
    } catch (_) {}
  }
}


