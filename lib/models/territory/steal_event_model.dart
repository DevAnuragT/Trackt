class StealEvent {
  final String id;
  final String stolenTerritoryId;
  final String previousOwnerId;
  final String newOwnerId;
  final double overlapPercentage;
  final String reason; // 'partial_conquest' | 'complete_conquest' | 'overlap'
  final DateTime stealDate;
  final double? stolenArea; // in square meters, optional if not provided by DB yet
  
  // Optional display names for users
  final String? previousOwnerName;
  final String? newOwnerName;

  StealEvent({
    required this.id,
    required this.stolenTerritoryId,
    required this.previousOwnerId,
    required this.newOwnerId,
    required this.overlapPercentage,
    required this.reason,
    required this.stealDate,
    this.stolenArea,
    this.previousOwnerName,
    this.newOwnerName,
  });

  factory StealEvent.fromJson(Map<String, dynamic> json) {
    return StealEvent(
      id: json['id'] as String,
      stolenTerritoryId: json['stolen_territory_id'] as String,
      previousOwnerId: json['previous_owner_id'] as String,
      newOwnerId: json['new_owner_id'] as String,
      overlapPercentage: (json['overlap_percentage'] as num).toDouble(),
      reason: (json['reason'] ?? 'overlap') as String,
      stealDate: DateTime.parse(json['steal_date'] as String),
      stolenArea: json['stolen_area'] == null ? null : (json['stolen_area'] as num).toDouble(),
    );
  }

  /// Factory method for creating StealEvent with user names from joined query
  factory StealEvent.fromJsonWithNames(Map<String, dynamic> json) {
    return StealEvent(
      id: json['id'] as String,
      stolenTerritoryId: json['stolen_territory_id'] as String,
      previousOwnerId: json['previous_owner_id'] as String,
      newOwnerId: json['new_owner_id'] as String,
      overlapPercentage: (json['overlap_percentage'] as num).toDouble(),
      reason: (json['reason'] ?? 'overlap') as String,
      stealDate: DateTime.parse(json['steal_date'] as String),
      stolenArea: json['stolen_area'] == null ? null : (json['stolen_area'] as num).toDouble(),
      previousOwnerName: json['previous_owner']?['display_name'] as String?,
      newOwnerName: json['new_owner']?['display_name'] as String?,
    );
  }

  String formatArea() {
    final area = stolenArea;
    if (area == null) return '';
    if (area >= 1000000) return '${(area / 1000000).toStringAsFixed(2)} km²';
    if (area >= 10000) return '${(area / 10000).toStringAsFixed(2)} ha';
    return '${area.toStringAsFixed(0)} m²';
  }
}


