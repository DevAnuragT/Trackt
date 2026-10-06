import 'dart:convert';
import 'territory_model.dart';

class RunSession {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double? distance;
  final Duration? duration;
  final List<LatLngPoint> rawPath;
  final RunStatus status;

  RunSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.distance,
    this.duration,
    required this.rawPath,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'distance': distance,
      'duration': duration?.inSeconds,
      'raw_path': jsonEncode(rawPath.map((p) => p.toJson()).toList()),
      'status': status.toString().split('.').last,
    };
  }

  factory RunSession.fromJson(Map<String, dynamic> json) {
    List<LatLngPoint> pathPoints = [];
    if (json['raw_path'] != null) {
      final pathData = jsonDecode(json['raw_path']) as List;
      pathPoints = pathData.map((p) => LatLngPoint.fromJson(p)).toList();
    }

    return RunSession(
      id: json['id'],
      userId: json['user_id'],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['start_time']),
      endTime: json['end_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['end_time'])
          : null,
      distance: json['distance']?.toDouble(),
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration'])
          : null,
      rawPath: pathPoints,
      status: RunStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RunStatus.active,
      ),
    );
  }

  RunSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    Duration? duration,
    List<LatLngPoint>? rawPath,
    RunStatus? status,
  }) {
    return RunSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      rawPath: rawPath ?? this.rawPath,
      status: status ?? this.status,
    );
  }
}

enum RunStatus {
  active,
  completed,
  cancelled,
}
