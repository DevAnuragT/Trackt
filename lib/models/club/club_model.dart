class Club {
  final String id;
  final String name;
  final String referralCode;
  final String creatorId;
  final DateTime createdAt;

  Club({
    required this.id,
    required this.name,
    required this.referralCode,
    required this.creatorId,
    required this.createdAt,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as String,
      name: json['name'] as String,
      referralCode: json['referral_code'] as String,
      creatorId: json['creator_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'referral_code': referralCode,
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Club(id: $id, name: $name, referralCode: $referralCode, creatorId: $creatorId, createdAt: $createdAt)';
  }
}
