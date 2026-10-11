import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/monad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonadService burner wallet', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generates and persists a burner wallet on first init', () async {
      final service = await MonadService().init();

      expect(service.walletAddress.value, isNotEmpty);
      expect(service.walletAddress.value, startsWith('0x'));
      expect(service.chainId, 10143);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('monad_burner_private_key'), isNotNull);
    });

    test('restores the same wallet from persisted key', () async {
      final first = await MonadService().init();
      final addr1 = first.walletAddress.value;

      // Second instance reads the persisted key: same address.
      final second = await MonadService().init();
      expect(second.walletAddress.value, addr1);
    });

    test('shortAddress is truncated for HUD display', () async {
      final service = await MonadService().init();
      final short = service.shortAddress;
      expect(short.contains('…'), isTrue);
      expect(short.length, lessThan(service.walletAddress.value.length));
    });
  });

  group('MonadService claim fallback (no contract configured)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('claimTerritoryOnChain returns a local proof hash when unset', () async {
      final service = await MonadService().init();

      final tx = await service.claimTerritoryOnChain(
        territoryId: '550e8400-e29b-41d4-a716-446655440000',
        centerLat: 40.7812,
        centerLng: -73.9665,
        areaSqMeters: 16850.0,
      );

      expect(tx, startsWith('0x'));
      expect(tx.length, 66); // 0x + 64 hex chars
      expect(service.lastTxOnChain.value, isFalse);
      expect(service.lastTxHash.value, tx);
      expect(service.isClaiming.value, isFalse);
    });

    test('getTracktTokenBalance returns 0 when token contract unset', () async {
      final service = await MonadService().init();
      expect(await service.getTracktTokenBalance(), 0.0);
    });

    test('explorerTxUrl builds a Monad Testnet explorer link', () async {
      final service = await MonadService().init();
      final url = service.explorerTxUrl('0xabc');
      expect(url, 'https://testnet.monadexplorer.com/tx/0xabc');
    });
  });
}
