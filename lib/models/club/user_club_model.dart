class UserClub {
  final String clubId;
  final String clubName;
  final String referralCode;
  final String creatorId;
  final String? creatorDisplayName;
  final DateTime clubCreatedAt;
  final DateTime joinedAt;
  final int memberCount;

  UserClub({
    required this.clubId,
    required this.clubName,
    required this.referralCode,
    required this.creatorId,
    this.creatorDisplayName,
    required this.clubCreatedAt,
    required this.joinedAt,
    required this.memberCount,
  });

  factory UserClub.fromJson(Map<String, dynamic> json) {
    return UserClub(
      clubId: json['club_id'] as String,
      clubName: json['club_name'] as String,
      referralCode: json['referral_code'] as String,
      creatorId: json['creator_id'] as String,
      creatorDisplayName: json['creator_display_name'] as String?,
      clubCreatedAt: DateTime.parse(json['club_created_at'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      memberCount: json['member_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'club_id': clubId,
      'club_name': clubName,
      'referral_code': referralCode,
      'creator_id': creatorId,
      'club_created_at': clubCreatedAt.toIso8601String(),
      'member_count': memberCount,
    };
  }

  @override
  String toString() {
    return 'UserClub(clubId: $clubId, clubName: $clubName, referralCode: $referralCode, creatorId: $creatorId, creatorDisplayName: $creatorDisplayName, clubCreatedAt: $clubCreatedAt, joinedAt: $joinedAt, memberCount: $memberCount)';
  }
}
