import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationService service = Get.find<NotificationService>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.refreshNotifications(),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: () => service.markAllAsRead(),
            tooltip: 'Mark all read',
          ),
        ],
      ),
      body: Obx(() {
        if (service.isLoading.value && service.notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        if (service.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                const SizedBox(height: 8),
                Text(
                  'Failed to load notifications',
                  style: TextStyle(color: Colors.red[300]),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => service.refreshNotifications(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (service.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, color: Colors.grey[600], size: 64),
                const SizedBox(height: 12),
                Text('No notifications yet', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: service.refreshNotifications,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index == service.notifications.length) {
                return Visibility(
                  visible: service.hasMoreNotifications.value,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => service.loadMoreNotifications(),
                      child: const Text('Load More'),
                    ),
                  ),
                );
              }
              final n = service.notifications[index];
              final bool isRead = n['is_read'] ?? false;
              final String type = n['type'] ?? 'system';
              final Map<String, dynamic> metadata = n['metadata'] ?? {};
              final String title = n['title'] ?? 'Notification';
              final String message = n['message'] ?? '';

              String areaInfo = '';
              if (metadata['stolen_area'] != null) {
                areaInfo = ' • ${_formatArea((metadata['stolen_area'] as num).toDouble())} stolen';
              } else if (metadata['conquered_area'] != null) {
                areaInfo = ' • ${_formatArea((metadata['conquered_area'] as num).toDouble())} gained';
              }

              return Container(
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey[900] : Colors.blue[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRead ? Colors.grey[700]! : Colors.blue[700]!,
                    width: isRead ? 1 : 2,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: _getNotificationIcon(type, isRead),
                  title: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: isRead ? Colors.grey[400] : Colors.grey[300],
                          fontSize: 13,
                        ),
                      ),
                      if (areaInfo.isNotEmpty)
                        Text(
                          areaInfo,
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRead)
                        IconButton(
                          icon: const Icon(Icons.mark_email_read, color: Colors.green),
                          onPressed: () => service.markAsRead(n['id']),
                          tooltip: 'Mark as read',
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => service.deleteNotification(n['id']),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: service.notifications.length + 1,
          ),
        );
      }),
    );
  }

  Widget _getNotificationIcon(String type, bool isRead) {
    IconData iconData;
    Color iconColor;
    switch (type) {
      case 'territory_conquest':
        iconData = Icons.flag;
        iconColor = Colors.green;
        break;
      case 'territory_loss':
        iconData = Icons.remove_circle;
        iconColor = Colors.red;
        break;
      case 'achievement':
        iconData = Icons.star;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = isRead ? Colors.grey[600]! : Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  String _formatArea(double area) {
    if (area >= 1000000) return '${(area / 1000000).toStringAsFixed(2)} km²';
    if (area >= 10000) return '${(area / 10000).toStringAsFixed(2)} ha';
    return '${area.toStringAsFixed(0)} m²';
  }
}


