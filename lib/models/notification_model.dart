import 'dart:convert';

class NotificationItem {
  final String id;
  final String userId;
  final String kind;
  final String? title;
  final String? body;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.kind,
    this.title,
    this.body,
    this.meta,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kind: (map['kind'] as String?) ?? 'territory_steal',
      title: map['title'] as String?,
      body: map['body'] as String?,
      meta: map['meta'] is String
          ? jsonDecode(map['meta'] as String) as Map<String, dynamic>
          : (map['meta'] as Map<String, dynamic>?),
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
    );
  }
}
