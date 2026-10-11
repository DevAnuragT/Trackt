import 'package:flutter_test/flutter_test.dart';
import 'package:trackt/models/territory/territory_model.dart';
import 'package:trackt/services/territory_service.dart';

Territory _t(String id, String owner) => Territory(
      id: id,
      ownerId: owner,
      boundaryPoints: const [],
      area: 100,
      createdAt: DateTime.now(),
      center: LatLngPoint(latitude: 0, longitude: 0, timestamp: DateTime.now()),
    );

void main() {
  group('Territory Shield protection (filterShielded)', () {
    final targets = [
      _t('a', 'me'),
      _t('b', '@Rival'),
      _t('c', 'me'),
      _t('d', '@Other'),
    ];

    test('removes the user\'s own territories when shield is active', () {
      final result = TerritoryService.filterShielded(
        targets,
        ownerId: 'me',
        shieldActive: true,
      );
      final ids = result.map((t) => t.id).toList();
      expect(ids, ['b', 'd']); // my territories a,c are protected
    });

    test('returns all targets when shield is inactive', () {
      final result = TerritoryService.filterShielded(
        targets,
        ownerId: 'me',
        shieldActive: false,
      );
      expect(result.length, 4);
    });

    test('returns all targets when owner is unknown', () {
      final result = TerritoryService.filterShielded(
        targets,
        ownerId: null,
        shieldActive: true,
      );
      expect(result.length, 4);
    });
  });
}
