import 'dart:convert';
import 'dart:math' as math;

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    if (v == 'true' || v == 't' || v == '1') return true;
    if (v == 'false' || v == 'f' || v == '0') return false;
  }
  return null;
}

class Territory {
  final String id;
  final String ownerId;
  final List<LatLngPoint> boundaryPoints;
  final List<RingPart>? boundaryRings; // Supports polygons with holes/multipolygons
  final double area; // in square meters
  final DateTime createdAt;
  final LatLngPoint center;
  final String? ownerColor; // Color hex string (e.g., "#FF0000")
  final int? renderLayer; // For proper map layering
  final bool? isConquered; // Whether this territory was conquered

  Territory({
    required this.id,
    required this.ownerId,
    required this.boundaryPoints,
    this.boundaryRings,
    required this.area,
    required this.createdAt,
    required this.center,
    this.ownerColor,
    this.renderLayer,
    this.isConquered,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'owner_id': ownerId,
      // Prefer ring structure if present; else flat points
      'boundary_points': boundaryRings != null
          ? jsonEncode(boundaryRings!.map((part) => part.toJson()).toList())
          : jsonEncode(boundaryPoints.map((p) => p.toSimpleJson()).toList()),
      'area': area,
      'created_at': createdAt.millisecondsSinceEpoch,
      'center_lat': center.latitude,
      'center_lng': center.longitude,
      'owner_color': ownerColor,
    };
    return map;
  }

  factory Territory.fromJson(Map<String, dynamic> json) {
    try {
      List<LatLngPoint> boundary = [];
      List<RingPart>? rings;
      if (json['boundary_points'] != null) {
        // Handle both cases: direct List or JSON string
        List boundaryData;
        if (json['boundary_points'] is String) {
          // If it's a JSON string, decode it
          boundaryData = jsonDecode(json['boundary_points']) as List;
        } else {
          // If it's already a List, use it directly
          boundaryData = json['boundary_points'] as List;
        }
        
        print('🔍 Territory.fromJson: boundaryData type: ${boundaryData.runtimeType}, length: ${boundaryData.length}');
        if (boundaryData.isNotEmpty) {
          print('🔍 Territory.fromJson: first element type: ${boundaryData.first.runtimeType}');
          if (boundaryData.first is Map) {
            print('🔍 Territory.fromJson: first element keys: ${(boundaryData.first as Map).keys.toList()}');
          }
        }
        
        // Detect ring-based structure: element with keys 'outer' and optional 'holes'
        if (boundaryData.isNotEmpty && boundaryData.first is Map &&
            (boundaryData.first as Map).containsKey('outer')) {
          print('🔍 Territory.fromJson: Detected ring structure, parsing ${boundaryData.length} ring parts');
          rings = boundaryData
              .where((e) => e != null && e is Map)
              .map<RingPart>((e) => RingPart.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          boundary = []; // Leave flat list empty when rings provided
          print('🔍 Territory.fromJson: Successfully parsed ${rings.length} ring parts');
        } else if (boundaryData.isNotEmpty && boundaryData.first is Map &&
                   (boundaryData.first as Map).containsKey('lat') && 
                   (boundaryData.first as Map).containsKey('lng')) {
          print('🔍 Territory.fromJson: Using flat boundary structure with ${boundaryData.length} points');
          boundary = boundaryData
              .where((p) => p != null && p is Map && p['lat'] != null && p['lng'] != null)
              .map((p) => LatLngPoint.fromSimpleJson(Map<String, dynamic>.from(p)))
              .toList();
        } else {
          print('🔍 Territory.fromJson: Unknown boundary structure, using empty boundary');
          boundary = [];
        }
      }

      // Additional safety checks for required fields
      final id = json['id']?.toString() ?? 'unknown';
      final ownerId = json['owner_id']?.toString() ?? 'unknown';
      final area = (json['area'] ?? 0.0).toDouble();
      final createdAtIndex = json['created_at'] ?? DateTime.now().millisecondsSinceEpoch;
      final centerLat = (json['center_lat'] ?? json['center']?['lat'] ?? 0.0).toDouble();
      final centerLng = (json['center_lng'] ?? json['center']?['lng'] ?? 0.0).toDouble();
      
      print('🔍 Territory.fromJson: Parsed values - id: $id, ownerId: $ownerId, area: $area, center: ($centerLat, $centerLng)');
      
      return Territory(
        id: id,
        ownerId: ownerId,
        boundaryPoints: boundary,
        boundaryRings: rings,
        area: area,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtIndex),
        center: LatLngPoint(
          latitude: centerLat,
          longitude: centerLng,
          timestamp: DateTime.fromMillisecondsSinceEpoch(createdAtIndex),
        ),
        ownerColor: json['owner_color'],
        renderLayer: (json['render_layer'] is num) ? (json['render_layer'] as num).toInt() : null,
        isConquered: _asBool(json['is_conquered']),
      );
    } catch (e) {
      print('❌ Error parsing Territory: $e');
      // Return a default territory if parsing fails
      return Territory(
        id: json['id'] ?? 'unknown',
        ownerId: json['owner_id'] ?? 'unknown',
        boundaryPoints: [],
        boundaryRings: [],
        area: 0.0,
        createdAt: DateTime.now(),
        center: LatLngPoint(
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
        ),
        ownerColor: '#808080',
        renderLayer: 0,
        isConquered: false,
      );
    }
  }
}

class RingPart {
  final List<LatLngPoint> outer;
  final List<List<LatLngPoint>> holes;

  RingPart({required this.outer, required this.holes});

  Map<String, dynamic> toJson() => {
        'outer': outer.map((p) => p.toSimpleJson()).toList(),
        'holes': holes.map((ring) => ring.map((p) => p.toSimpleJson()).toList()).toList(),
      };

  factory RingPart.fromJson(Map<String, dynamic> json) {
    print('🔍 RingPart.fromJson: parsing outer ring with ${json['outer']?.length ?? 0} points');
    print('🔍 RingPart.fromJson: parsing holes with ${json['holes']?.length ?? 0} hole rings');
    
    try {
      // Parse outer ring: list of {"lat": ..., "lng": ...} objects
      final outer = (json['outer'] as List? ?? [])
          .where((p) => p != null && p['lat'] != null && p['lng'] != null)
          .map((p) => LatLngPoint.fromSimpleJson(Map<String, dynamic>.from(p)))
          .toList();
      
      // Parse holes: list of rings, each ring is a list of {"lat": ..., "lng": ...} objects
      final holes = (json['holes'] as List? ?? [])
          .map<List<LatLngPoint>>((ring) => (ring as List? ?? [])
              .where((p) => p != null && p['lat'] != null && p['lng'] != null)
              .map((p) => LatLngPoint.fromSimpleJson(Map<String, dynamic>.from(p)))
              .toList())
          .where((ring) => ring.isNotEmpty)
          .toList();
      
      print('🔍 RingPart.fromJson: successfully parsed outer ring with ${outer.length} points and ${holes.length} holes');
      return RingPart(outer: outer, holes: holes);
    } catch (e) {
      print('❌ Error parsing RingPart: $e');
      // Return a default empty ring if parsing fails
      return RingPart(outer: [], holes: []);
    }
  }
}

class LatLngPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;

  LatLngPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
  });

  // For detailed storage (run tracking)
  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'speed': speed,
    };
  }

  // For simplified storage (territories)
  Map<String, dynamic> toSimpleJson() {
    return {
      'lat': latitude,
      'lng': longitude,
    };
  }

  factory LatLngPoint.fromJson(Map<String, dynamic> json) {
    return LatLngPoint(
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lng'] ?? 0.0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      accuracy: json['accuracy']?.toDouble(),
      speed: json['speed']?.toDouble(),
    );
  }

  factory LatLngPoint.fromSimpleJson(Map<String, dynamic> json) {
    return LatLngPoint(
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lng'] ?? 0.0).toDouble(),
      timestamp: DateTime.now(), // Default timestamp for simplified data
    );
  }

  // Distance calculation using Haversine formula
  double distanceTo(LatLngPoint other) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(other.latitude - latitude);
    final double dLng = _toRadians(other.longitude - longitude);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) * math.cos(_toRadians(other.latitude)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
