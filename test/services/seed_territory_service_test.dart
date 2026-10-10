import 'package:flutter_test/flutter_test.dart';
import 'package:trackt/services/seed_territory_service.dart';

void main() {
  group('SeedTerritoryService', () {
    final service = SeedTerritoryService();

    test('buildAll generates seeds for every city', () {
      final all = service.buildAll();
      final expected =
          SeedTerritoryService.cities.fold<int>(0, (sum, c) => sum + c.count);
      expect(all.length, expected);
      expect(all.length, greaterThanOrEqualTo(45)); // vibrant battlefield
    });

    test('buildAll is cached (stable identity across calls)', () {
      expect(identical(service.buildAll(), service.buildAll()), isTrue);
    });

    test('every seed is a closed organic rival polygon', () {
      for (final t in service.buildAll()) {
        expect(t.id, startsWith('seed-'));
        expect(t.ownerId, startsWith('@')); // rival username, not the user
        expect(t.ownerColor, isNotNull);
        expect(t.ownerColor, startsWith('#'));
        expect(t.area, greaterThan(0));
        expect(t.boundaryPoints.length, greaterThan(10));
        // Closed loop: first point == last point.
        expect(t.boundaryPoints.first.latitude, t.boundaryPoints.last.latitude);
        expect(t.boundaryPoints.first.longitude, t.boundaryPoints.last.longitude);
      }
    });

    test('seeds use only the defined rival colors', () {
      final palette = SeedTerritoryService.rivals.map((r) => r.colorHex).toSet();
      for (final t in service.buildAll()) {
        expect(palette.contains(t.ownerColor), isTrue);
      }
    });

    test('near() filters seeds to a radius around a point', () {
      // Central Park NYC anchor: should find NYC seeds, exclude London/SF.
      final nyc = service.near(40.7812, -73.9665, radiusMeters: 3000);
      expect(nyc, isNotEmpty);
      expect(nyc.length, lessThan(service.buildAll().length));

      // Mid-ocean: no seeds nearby.
      final ocean = service.near(0.0, -30.0, radiusMeters: 3000);
      expect(ocean, isEmpty);
    });
  });
}
