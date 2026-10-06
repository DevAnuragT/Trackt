class ClubMember {
  final String userId;
  final String? userEmail;
  final String? displayName;
  final DateTime joinedAt;

  ClubMember({
    required this.userId,
    this.userEmail,
    this.displayName,
    required this.joinedAt,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String?,
      displayName: json['display_name'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_email': userEmail,
      'display_name': displayName,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ClubMember(userId: $userId, userEmail: $userEmail, displayName: $displayName, joinedAt: $joinedAt)';
  }
}
