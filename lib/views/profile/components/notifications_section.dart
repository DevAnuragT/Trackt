import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/notification_service.dart';

class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<NotificationService>();
    
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Obx(() {
                  if (service.unreadCount.value > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${service.unreadCount.value}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => service.refreshNotifications(),
                    icon: const Icon(Icons.refresh, color: Colors.blue),
                    label: const Text('Refresh', style: TextStyle(color: Colors.blue)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => service.markAllAsRead(),
                    icon: const Icon(Icons.mark_email_read, color: Colors.green),
                    label: const Text('Mark All Read', style: TextStyle(color: Colors.green)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Obx(() {
              if (service.isLoading.value) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
                );
              }
              
              if (service.hasError.value) {
                return Center(
                  child: Column(
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
                    children: [
                      Icon(Icons.notifications_none, color: Colors.grey[600], size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'No notifications yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'ll get notified when territories are conquered',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              
              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: service.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = service.notifications[index];
                      final isRead = notification['is_read'] ?? false;
                      final type = notification['type'] ?? 'system';
                      final metadata = notification['metadata'] ?? {};
                      
                      return _buildNotificationTile(notification, service, isRead, type, metadata);
                    },
                  ),
                  
                  // Load more button
                  if (service.hasMoreNotifications.value)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () => service.loadMoreNotifications(),
                          child: const Text('Load More'),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    Map<String, dynamic> notification,
    NotificationService service,
    bool isRead,
    String type,
    Map<String, dynamic> metadata,
  ) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['created_at'];
    
    // Get area information from metadata
    String areaInfo = '';
    if (metadata['stolen_area'] != null) {
      areaInfo = ' • ${_formatArea(metadata['stolen_area'].toDouble())} stolen';
    } else if (metadata['conquered_area'] != null) {
      areaInfo = ' • ${_formatArea(metadata['conquered_area'].toDouble())} gained';
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
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
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
                onPressed: () => service.markAsRead(notification['id']),
                tooltip: 'Mark as read',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => service.deleteNotification(notification['id']),
              tooltip: 'Delete notification',
            ),
          ],
        ),
      ),
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
    if (area >= 1000000) {
      return '${(area / 1000000).toStringAsFixed(2)} km²';
    } else if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(2)} ha';
    } else {
      return '${area.toStringAsFixed(0)} m²';
    }
  }

  String _formatTimeAgo(dynamic createdAt) {
    try {
      if (createdAt == null) return 'Unknown time';
      
      DateTime date;
      if (createdAt is String) {
        date = DateTime.parse(createdAt);
      } else if (createdAt is DateTime) {
        date = createdAt;
      } else {
        return 'Unknown time';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }
}