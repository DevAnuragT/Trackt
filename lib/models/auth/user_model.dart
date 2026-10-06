class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
