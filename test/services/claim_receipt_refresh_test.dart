import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/embedded_wallet_service.dart';
import 'package:trackt/services/monad_service.dart';

const address = '0x1111111111111111111111111111111111111111';
const contract = '0x2222222222222222222222222222222222222222';
final hash = '0x${List.filled(64, 'b').join()}';

class _Wallet extends EmbeddedWalletService {
  _Wallet() : super(currentAccountId: () => 'test-account') {
    isSelected.value = true;
    walletAddress.value = address;
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required String data,
    required int chainId,
    required BigInt gas,
  }) async => hash;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'MONAD_TERRITORY_CONTRACT=$contract');
  });
  tearDown(dotenv.clean);

  Future<MonadService> service({required bool receiptSucceeded}) async {
    bool mined = false;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final Object? result;
      switch (body['method']) {
        case 'eth_chainId':
          result = '0x279f';
        case 'eth_estimateGas':
          result = '0x124f8';
        case 'eth_getBalance':
          result = mined ? '0x1bc16d674ec80000' : '0xde0b6b3a7640000';
        case 'eth_getTransactionReceipt':
          mined = receiptSucceeded;
          result = {
            'transactionHash': hash,
            'transactionIndex': '0x0',
            'blockHash': '0x${List.filled(64, 'a').join()}',
            'blockNumber': '0x1',
            'cumulativeGasUsed': '0x124f8',
            'gasUsed': '0x124f8',
            'contractAddress': null,
            'from': address,
            'to': contract,
            'logs': [],
            'status': receiptSucceeded ? '0x1' : '0x0',
          };
        default:
          throw StateError('Unexpected RPC method ${body['method']}');
      }
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
        200,
      );
    });
    final monad = await MonadService(
      embeddedWallet: _Wallet(),
      client: client,
    ).init();
    await Future<void>.delayed(Duration.zero);
    expect(monad.monBalance.value, 1);
    return monad;
  }

  test(
    'refreshes wallet balances after a successful receipt, not just broadcast',
    () async {
      final monad = await service(receiptSucceeded: true);
      await monad.claimTerritoryOnChain(
        territoryId: '550e8400-e29b-41d4-a716-446655440000',
        centerLat: 40.7812,
        centerLng: -73.9665,
        areaSqMeters: 16850,
      );
      await Future<void>.delayed(Duration.zero);
      expect(monad.lastTxOnChain.value, true);
      expect(monad.monBalance.value, 2);
      expect(monad.lastClaimError.value, isNull);
      monad.onClose();
    },
  );

  test('surfaces a reverted receipt without calling it confirmed', () async {
    final monad = await service(receiptSucceeded: false);
    await monad.claimTerritoryOnChain(
      territoryId: '550e8400-e29b-41d4-a716-446655440000',
      centerLat: 40.7812,
      centerLng: -73.9665,
      areaSqMeters: 16850,
    );
    await Future<void>.delayed(Duration.zero);
    expect(monad.lastTxOnChain.value, true);
    expect(monad.lastClaimError.value, contains('reverted'));
    expect(monad.monBalance.value, 1);
    monad.onClose();
  });
}
