import 'dart:math' as math;

import 'package:get/get.dart';

import '../models/territory/territory_model.dart';

/// A fictional rival runner that owns seeded territories on the map.
class RivalProfile {
  final String username;
  final String colorHex;
  const RivalProfile(this.username, this.colorHex);
}

/// Anchor point for a cluster of seeded rival territories.
class SeedCity {
  final String name;
  final double lat;
  final double lng;
  final int count;
  const SeedCity(this.name, this.lat, this.lng, this.count);
}

/// Pre-populates the map with colorful rival territories across major tech
/// capitals so a judge opening the app anywhere sees a vibrant, active
/// battlefield ready to be attacked and conquered — no live users required.
///
/// Seeds are deterministic (seeded RNG), generated once and cached.
class SeedTerritoryService extends GetxService {
  static const List<RivalProfile> rivals = [
    RivalProfile('@MonadRunner', '#EF4444'), // Red
    RivalProfile('@SatoshiSprint', '#10B981'), // Green
    RivalProfile('@GmonadAthlete', '#F59E0B'), // Amber
    RivalProfile('@NadNomad', '#8B5CF6'), // Purple
    RivalProfile('@BlockPacer', '#00F5D4'), // Neon cyan
  ];

  static const List<SeedCity> cities = [
    SeedCity('New York', 40.7812, -73.9665, 16),
    SeedCity('San Francisco', 37.7989, -122.4662, 16),
    SeedCity('London', 51.5048, -0.1650, 16),
  ];

  List<Territory>? _cache;

  /// All seeded rival territories across every seeded city (cached).
  List<Territory> buildAll() {
    final cached = _cache;
    if (cached != null) return cached;

    final list = <Territory>[];
    for (final city in cities) {
      final rng = math.Random(city.name.hashCode);
      for (int i = 0; i < city.count; i++) {
        // Scatter centers within roughly 2.5 km of the city anchor.
        final cLat = city.lat + (rng.nextDouble() - 0.5) * 0.045;
        final cLng = city.lng + (rng.nextDouble() - 0.5) * 0.055;
        final radius = 70.0 + rng.nextDouble() * 90.0; // 70–160 m
        final rival = rivals[(i + city.name.length) % rivals.length];
        list.add(_buildTerritory(cLat, cLng, radius, rival, '${city.name}-$i', rng));
      }
    }
    _cache = list;
    return list;
  }

  /// Seeded territories whose center is within [radiusMeters] of (lat, lng).
  List<Territory> near(double lat, double lng, {double radiusMeters = 3000}) {
    final center = LatLngPoint(latitude: lat, longitude: lng, timestamp: DateTime.now());
    return buildAll()
        .where((t) => center.distanceTo(t.center) <= radiusMeters)
        .toList();
  }

  Territory _buildTerritory(
    double lat,
    double lng,
    double radius,
    RivalProfile rival,
    String tag,
    math.Random rng,
  ) {
    final now = DateTime.now();
    const int n = 28;
    // Organic perturbation so rivals look like real park loops, not circles.
    final p1 = 0.12 + rng.nextDouble() * 0.12;
    final p2 = 0.08 + rng.nextDouble() * 0.10;
    final pts = <LatLngPoint>[];
    for (int i = 0; i <= n; i++) {
      final angle = (i / n) * 2 * math.pi;
      final r = radius * (1.0 + p1 * math.cos(2 * angle) - p2 * math.sin(3 * angle));
      final latOff = (r * math.cos(angle)) / 111320.0;
      final cosLat = math.cos(lat * math.pi / 180.0);
      final lngOff =
          (r * math.sin(angle)) / (111320.0 * (cosLat.abs() > 0.0001 ? cosLat : 1.0));
      pts.add(LatLngPoint(
        latitude: lat + latOff,
        longitude: lng + lngOff,
        timestamp: now,
      ));
    }

    return Territory(
      id: 'seed-$tag',
      ownerId: rival.username,
      boundaryPoints: pts,
      area: math.pi * radius * radius,
      createdAt: now.subtract(Duration(hours: 1 + rng.nextInt(240))),
      center: LatLngPoint(latitude: lat, longitude: lng, timestamp: now),
      ownerColor: rival.colorHex,
      renderLayer: 0,
      isConquered: false,
    );
  }
}
