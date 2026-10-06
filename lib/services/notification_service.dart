import 'dart:async';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

class NotificationService extends GetxService {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Reactive variables
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;

  // Pagination
  final RxInt currentPage = 0.obs;
  final RxBool hasMoreNotifications = true.obs;
  static const int notificationsPerPage = 20;
  StreamSubscription? _authSub;

  @override
  void onInit() {
    super.onInit();
    // Load notifications when service initializes
    loadNotifications();

    // Auto-clear and reload on auth changes to prevent showing previous user's notifications
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      try {
        notifications.clear();
        unreadCount.value = 0;
        currentPage.value = 0;
        hasMoreNotifications.value = true;

        final newUserId = Supabase.instance.client.auth.currentUser?.id;
        if (newUserId != null) {
          await loadNotifications(refresh: true);
        }
      } catch (_) {}
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _authSub = null;
    super.onClose();
  }

  /// Load user notifications from Supabase
  Future<void> loadNotifications({bool refresh = false}) async {
    try {
      if (refresh) {
        currentPage.value = 0;
        hasMoreNotifications.value = true;
        notifications.clear();
      }

      if (!hasMoreNotifications.value) return;

      isLoading.value = true;
      hasError.value = false;

      print('📱 Loading notifications for page ${currentPage.value}...');

      // Call the database function to get notifications
      final response = await _supabase.rpc('get_user_notifications', params: {
        'p_user_id': _databaseService.currentUserId,
        'p_limit': notificationsPerPage,
        'p_offset': currentPage.value * notificationsPerPage,
      });

      if (response != null && response is List) {
        final newNotifications = response.cast<Map<String, dynamic>>();
        
        if (refresh) {
          notifications.clear();
        }
        
        notifications.addAll(newNotifications);
        
        // Check if we have more notifications
        hasMoreNotifications.value = newNotifications.length == notificationsPerPage;
        currentPage.value++;
        
        print('✅ Loaded ${newNotifications.length} notifications (total: ${notifications.length})');
      }

      // Update unread count
      await updateUnreadCount();
      
    } catch (e) {
      print('❌ Error loading notifications: $e');
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMoreNotifications() async {
    if (!hasMoreNotifications.value || isLoading.value) return;
    await loadNotifications();
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refreshNotifications() async {
    await loadNotifications(refresh: true);
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      print('📱 Marking notification $notificationId as read...');
      
      final response = await _supabase.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });

      if (response == true) {
        // Update local notification state
        final index = notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          notifications[index]['is_read'] = true;
          notifications.refresh();
        }
        
        // Update unread count
        await updateUnreadCount();
        
        print('✅ Notification marked as read');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Delete notification (soft delete)
  Future<bool> deleteNotification(String notificationId) async {
    try {
      print('📱 Deleting notification $notificationId...');
      
      final response = await _supabase.rpc('delete_notification', params: {
        'p_notification_id': notificationId,
      });

      if (response == true) {
        // Remove from local list
        notifications.removeWhere((n) => n['id'] == notificationId);
        
        // Update unread count
        await updateUnreadCount();
        
        print('✅ Notification deleted');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Update unread notification count
  Future<void> updateUnreadCount() async {
    try {
      final response = await _supabase.rpc('get_unread_notification_count', params: {
        'p_user_id': _databaseService.currentUserId,
      });

      if (response != null) {
        unreadCount.value = response;
        print('📱 Unread notifications: ${unreadCount.value}');
      }
    } catch (e) {
      print('❌ Error updating unread count: $e');
      unreadCount.value = 0;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      print('📱 Marking all notifications as read...');
      
      // Get all unread notifications
      final unreadNotifications = notifications.where((n) => n['is_read'] == false).toList();
      
      if (unreadNotifications.isEmpty) {
        print('ℹ️ No unread notifications to mark');
        return true;
      }

      // Mark each as read
      bool allSuccess = true;
      for (final notification in unreadNotifications) {
        final success = await markAsRead(notification['id']);
        if (!success) allSuccess = false;
      }

      if (allSuccess) {
        print('✅ All notifications marked as read');
        await updateUnreadCount();
      }

      return allSuccess;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get notification by ID
  Map<String, dynamic>? getNotificationById(String id) {
    try {
      return notifications.firstWhere((n) => n['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Get notifications by type
  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return notifications.where((n) => n['type'] == type).toList();
  }

  /// Get unread notifications
  List<Map<String, dynamic>> getUnreadNotifications() {
    return notifications.where((n) => n['is_read'] == false).toList();
  }

  /// Check if user has unread notifications
  bool get hasUnreadNotifications => unreadCount.value > 0;

  /// Get notification count
  int get notificationCount => notifications.length;

  /// Clear all notifications (for testing)
  Future<void> clearAllNotifications() async {
    try {
      print('📱 Clearing all notifications...');
      
      // Mark all as deleted
      for (final notification in notifications) {
        await deleteNotification(notification['id']);
      }
      
      notifications.clear();
      unreadCount.value = 0;
      
      print('✅ All notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }
}