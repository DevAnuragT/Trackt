import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:privy_flutter/src/logging/logger_service.dart';
import 'package:privy_flutter/src/logging/privy_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/crypto.dart';
import 'package:trackt/services/embedded_wallet_service.dart';
import 'package:trackt/services/monad_service.dart';

const walletAddress = '0x1111111111111111111111111111111111111111';
const contractAddress = '0x2222222222222222222222222222222222222222';

class _Logger extends Fake implements PrivyLogger {
  @override
  void debug(String message) {}

  @override
  void error(String message) {}
}

class _InterruptedPreferences extends Fake implements SharedPreferences {
  final removed = <String>[];

  @override
  Set<String> getKeys() => {
    'monad_burner_private_key',
    'isFirstLaunch',
    'username',
  };

  @override
  Future<bool> remove(String key) async {
    removed.add(key);
    throw StateError('Simulated interrupted cache cleanup');
  }
}

class _User extends Fake implements PrivyUser {
  @override
  final embeddedEthereumWallets = [
    EmbeddedEthereumWallet(address: walletAddress, hdWalletIndex: 0),
  ];
}

class _Sdk extends Fake implements Privy {
  AuthState state = Authenticated(_User());
  int logoutCount = 0;

  @override
  AuthState get currentAuthState => state;

  @override
  Future<AuthState> getAuthState() async => state;

  @override
  Future<void> onNetworkRestored() async {}

  @override
  Future<void> logout() async {
    logoutCount++;
    state = const Unauthenticated();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('privy_flutter');
  final services = <EmbeddedWalletService>[];

  setUp(() {
    LoggerService.initializeLogger(_Logger());
    dotenv.clean();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    for (final service in services) {
      service.onClose();
    }
    services.clear();
    dotenv.clean();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  EmbeddedWalletService create(_Sdk sdk, {String? Function()? account}) {
    final service = EmbeddedWalletService(
      currentAccountId: account ?? () => 'account-1',
      sdk: sdk,
      appId: 'test-app',
      clientId: 'test-client',
    );
    services.add(service);
    return service;
  }

  MockClient rpc({
    Future<void> Function()? onEstimate,
    String chainId = '0x279f',
  }) => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final method = body['method'];
    final String result;
    switch (method) {
      case 'eth_getBalance':
        result = '0x1bc16d674ec80000';
      case 'eth_chainId':
        result = chainId;
      case 'eth_estimateGas':
        if (onEstimate != null) await onEstimate();
        result = '0x124f8';
      default:
        throw StateError('Unexpected RPC method: $method');
    }
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
    );
  });

  test(
    'a completed claim routes the exact registry ABI through the selected Privy wallet',
    () async {
      dotenv.testLoad(fileInput: 'MONAD_TERRITORY_CONTRACT=$contractAddress');
      Map<String, dynamic>? transaction;
      final hash = '0x${List.filled(64, 'b').join()}';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            transaction = jsonDecode((args['params'] as List).single as String);
            return {'method': 'eth_sendTransaction', 'data': hash};
          });
      final embedded = await create(_Sdk()).init();
      await embedded.activateExistingSession();
      final monad = await MonadService(
        embeddedWallet: embedded,
        client: rpc(),
      ).init();
      final originalBurner = monad.burnerAddress;
      final actual = await monad.claimTerritoryOnChain(
        territoryId: '550e8400-e29b-41d4-a716-446655440000',
        centerLat: 40.7812,
        centerLng: -73.9665,
        areaSqMeters: 16850,
      );
      expect(actual, hash);
      expect(monad.lastTxOnChain.value, true);
      expect(monad.monBalance.value, 2.0);
      expect(monad.walletAddress.value.toLowerCase(), walletAddress);
      expect(transaction!['from'], walletAddress);
      expect((transaction!['to'] as String).toLowerCase(), contractAddress);
      final encoded = transaction!['data'] as String;
      final selector = bytesToHex(
        keccakUtf8('claimTerritory(uint256,int256,int256,uint256)'),
        include0x: true,
      ).substring(0, 10);
      expect(encoded.substring(0, 10), selector);
      expect(encoded.length, 266);
      final words = List.generate(
        4,
        (index) => BigInt.parse(
          encoded.substring(10 + index * 64, 10 + (index + 1) * 64),
          radix: 16,
        ),
      );
      expect(
        words[0],
        BigInt.parse('550e8400e29b41d4a716446655440000', radix: 16),
      );
      expect(words[1], BigInt.from(40781200));
      expect(words[2] - (BigInt.one << 256), BigInt.from(-73966500));
      expect(words[3], BigInt.from(16850));
      await embedded.useBurner();
      expect(monad.walletAddress.value, originalBurner);
      monad.onClose();
    },
  );

  test(
    'source switching during gas estimation aborts rather than signing with another wallet',
    () async {
      dotenv.testLoad(fileInput: 'MONAD_TERRITORY_CONTRACT=$contractAddress');
      int signatures = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            signatures++;
            return null;
          });
      final embedded = await create(_Sdk()).init();
      await embedded.activateExistingSession();
      final monad = await MonadService(
        embeddedWallet: embedded,
        client: rpc(onEstimate: embedded.useBurner),
      ).init();
      await monad.claimTerritoryOnChain(
        territoryId: '550e8400-e29b-41d4-a716-446655440000',
        centerLat: 40.7812,
        centerLng: -73.9665,
        areaSqMeters: 16850,
      );

      expect(signatures, 0);
      expect(monad.lastTxOnChain.value, false);
      expect(monad.lastClaimError.value, isNotNull);
      monad.onClose();
    },
  );

  test(
    'preserves burner credentials when clearing account-specific preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'monad_burner_private_key': 'preserved-key',
        'isFirstLaunch': false,
        'username': 'old-user',
        EmbeddedWalletService.selectedPreference: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await MonadService.clearUserPreferencesPreservingWallet(prefs);
      expect(prefs.getString('monad_burner_private_key'), 'preserved-key');
      expect(prefs.getString('username'), isNull);
      expect(prefs.getBool('isFirstLaunch'), false);
      expect(prefs.getBool(EmbeddedWalletService.selectedPreference), isNull);
    },
  );

  test('a wrong-chain RPC cannot trigger a Privy signature', () async {
    dotenv.testLoad(fileInput: 'MONAD_TERRITORY_CONTRACT=$contractAddress');
    int signatures = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          signatures++;
          return null;
        });
    final embedded = await create(_Sdk()).init();
    await embedded.activateExistingSession();
    final monad = await MonadService(
      embeddedWallet: embedded,
      client: rpc(chainId: '0x8f'),
    ).init();
    await monad.claimTerritoryOnChain(
      territoryId: '550e8400-e29b-41d4-a716-446655440000',
      centerLat: 40.7812,
      centerLng: -73.9665,
      areaSqMeters: 16850,
    );
    expect(signatures, 0);
    expect(monad.lastTxOnChain.value, false);
    expect(monad.lastClaimError.value, isNotNull);
    monad.onClose();
  });

  test(
    'interrupted cache cleanup never removes or rewrites wallet credentials',
    () async {
      final prefs = _InterruptedPreferences();
      await expectLater(
        MonadService.clearUserPreferencesPreservingWallet(prefs),
        throwsStateError,
      );
      expect(prefs.removed, ['username']);
    },
  );

  test(
    'selects Privy only after an explicit activation and preserves the burner',
    () async {
      SharedPreferences.setMockInitialValues({
        'monad_burner_private_key': 'preserved-key',
      });
      final service = await create(_Sdk()).init();
      expect(service.isSelected.value, false);
      await service.activateExistingSession();
      expect(service.isSelected.value, true);
      expect(service.walletAddress.value, walletAddress);
      await service.useBurner();
      expect(service.isSelected.value, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('monad_burner_private_key'), 'preserved-key');
    },
  );

  test('restores the selected wallet for the same Trackt account', () async {
    final sdk = _Sdk();
    final first = await create(sdk).init();
    await first.activateExistingSession();
    final second = await create(sdk).init();
    await second.restoreSession();
    expect(second.isSelected.value, true);
    expect(second.walletAddress.value, walletAddress);
  });

  test(
    'does not restore another Trackt account or silently select a burner offline',
    () async {
      final sdk = _Sdk();
      final first = await create(sdk).init();
      await first.activateExistingSession();
      final other = await create(sdk, account: () => 'account-2').init();
      expect(other.isSelected.value, false);
      sdk.state = const AuthenticatedUnverified();
      await first.restoreSession();
      expect(first.isSelected.value, true);
      expect(first.walletAddress.value, isEmpty);
      expect(first.error.value, contains('Reconnect'));
    },
  );

  test(
    'sends real ABI call data and Testnet chain/gas through Privy signing',
    () async {
      final hash = '0x${List.filled(64, 'a').join()}';
      Map<String, dynamic>? transaction;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'ethSendRpcRequest');
            final args = Map<String, dynamic>.from(call.arguments as Map);
            expect(args['method'], 'eth_sendTransaction');
            expect(args['walletAddress'], walletAddress);
            transaction = jsonDecode((args['params'] as List).single as String);
            return {'method': 'eth_sendTransaction', 'data': hash};
          });
      final service = await create(_Sdk()).init();
      await service.activateExistingSession();
      expect(
        await service.sendTransaction(
          to: contractAddress,
          data: '0x1234',
          chainId: 10143,
          gas: BigInt.from(75000),
        ),
        hash,
      );
      expect(transaction, {
        'from': walletAddress,
        'to': contractAddress,
        'data': '0x1234',
        'chainId': '0x279f',
        'gas': '0x124f8',
        'value': '0x0',
      });
    },
  );

  test(
    'rejects expired sessions and account switching instead of signing as the burner',
    () async {
      final sdk = _Sdk();
      String? account = 'account-1';
      final service = await create(sdk, account: () => account).init();
      await service.activateExistingSession();
      account = 'account-2';
      await expectLater(
        service.sendTransaction(
          to: contractAddress,
          data: '0x1234',
          chainId: 10143,
          gas: BigInt.one,
        ),
        throwsStateError,
      );
      account = 'account-1';
      sdk.state = const Unauthenticated();
      await expectLater(
        service.sendTransaction(
          to: contractAddress,
          data: '0x1234',
          chainId: 10143,
          gas: BigInt.one,
        ),
        throwsStateError,
      );
      expect(service.isSelected.value, true);
    },
  );

  test('sign out disconnects Privy but never deletes the burner key', () async {
    SharedPreferences.setMockInitialValues({
      'monad_burner_private_key': 'preserved-key',
    });
    final sdk = _Sdk();
    final service = await create(sdk).init();
    await service.activateExistingSession();
    await service.disconnectOnSignOut();
    expect(sdk.logoutCount, 1);
    expect(service.isSelected.value, false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monad_burner_private_key'), 'preserved-key');
  });

  test(
    'missing Privy client configuration is visible and never deletes a wallet',
    () async {
      final service = await EmbeddedWalletService(
        currentAccountId: () => 'account-1',
        appId: 'test-app',
        clientId: '',
      ).init();
      expect(service.isConfigured, false);
      expect(service.error.value, contains('Client ID'));
      await expectLater(
        service.sendEmailCode('test@example.invalid'),
        throwsStateError,
      );
    },
  );
}
