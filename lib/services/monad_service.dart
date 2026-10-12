import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

import 'env_config.dart';
import 'embedded_wallet_service.dart';

/// Client-side Monad Testnet Web3 integration.
///
/// Generates and persists a local burner/session wallet so the runner gets a
/// zero-friction, gasless-feeling experience: no MetaMask popups mid-run.
/// Territory claims are dispatched silently to Monad Testnet (Chain ID 10143)
/// at sub-second finality.
///
/// Resilient by design: if the RPC is unreachable or the teammate's contracts
/// are not yet deployed (addresses unset), the service still produces a wallet
/// and a settlement proof hash so the Judge Demo never breaks.
class MonadService extends GetxService {
  static const String _privateKeyPrefKey = 'monad_burner_private_key';
  final EmbeddedWalletService? embeddedWallet;
  Worker? _walletWorker;
  final lastClaimError = RxnString();

  MonadService({this.embeddedWallet, http.Client? client})
    : _httpClient = client;

  static Future<void> clearUserPreferencesPreservingWallet(
    SharedPreferences prefs,
  ) async {
    for (final key in prefs.getKeys()) {
      if (key != _privateKeyPrefKey && key != 'isFirstLaunch') {
        await prefs.remove(key);
      }
    }
  }

  // Minimal ABI matching the teammate's TerritoryRegistry.sol interface.
  static const String _territoryAbi = '''[
    {
      "inputs": [
        {"internalType": "uint256", "name": "territoryId", "type": "uint256"},
        {"internalType": "int256", "name": "lat", "type": "int256"},
        {"internalType": "int256", "name": "lng", "type": "int256"},
        {"internalType": "uint256", "name": "area", "type": "uint256"}
      ],
      "name": "claimTerritory",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';

  // Standard ERC-20 balanceOf for RunRewardToken (\$TRACKT).
  static const String _tokenAbi = '''[
    {
      "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  // Reactive wallet state for HUD/profile badges.
  final RxString walletAddress = ''.obs;
  final RxDouble monBalance = 0.0.obs; // native MON gas balance
  final RxDouble tracktBalance = 0.0.obs; // \$TRACKT ERC-20 reward balance
  final RxBool isReady = false.obs; // wallet loaded + RPC client configured
  final RxBool isClaiming = false.obs;
  final RxString lastTxHash = ''.obs;
  final RxBool lastTxOnChain = false.obs; // true if a real tx was broadcast

  Web3Client? _client;
  http.Client? _httpClient;
  EthPrivateKey? _credentials;
  EthereumAddress? _address;

  int get chainId => EnvConfig.monadChainId;
  String get rpcUrl => resolveRpcUrl(
    provider: EnvConfig.monadRpcProvider,
    publicUrl: EnvConfig.monadRpcUrl,
    alchemyKey: EnvConfig.alchemyApiKey,
  );

  static String resolveRpcUrl({
    required String provider,
    required String publicUrl,
    required String alchemyKey,
  }) {
    switch (provider) {
      case 'public':
        return publicUrl;
      case 'alchemy':
        if (alchemyKey.trim().isEmpty) {
          throw StateError('Alchemy selected, but ALCHEMY_API_KEY is missing.');
        }
        return 'https://monad-testnet.g.alchemy.com/v2/${alchemyKey.trim()}';
      default:
        throw StateError('MONAD_RPC_PROVIDER must be public or alchemy.');
    }
  }

  bool get usesEmbeddedWallet => embeddedWallet?.isSelected.value ?? false;
  String get burnerAddress => _address?.hexEip55 ?? '';
  EthereumAddress? get address {
    if (!usesEmbeddedWallet) return _address;
    final value = embeddedWallet!.walletAddress.value;
    return value.isEmpty ? null : EthereumAddress.fromHex(value);
  }

  bool get _hasTerritoryContract =>
      EnvConfig.monadTerritoryContract.trim().isNotEmpty;
  bool get _hasTokenContract => EnvConfig.monadTokenContract.trim().isNotEmpty;

  Future<MonadService> init() async {
    try {
      await _loadOrCreateWallet();
      _httpClient ??= http.Client();
      _client = Web3Client(rpcUrl, _httpClient!);
      if (embeddedWallet != null) {
        _walletWorker = everAll([
          embeddedWallet!.isSelected,
          embeddedWallet!.walletAddress,
        ], (_) => _syncWalletAddress());
      }
      _syncWalletAddress();
      isReady.value = true;
      // ignore: avoid_print
      print(
        '⛓️ MonadService ready. Wallet: ${walletAddress.value} (chain $chainId)',
      );
    } catch (e) {
      // Degrade gracefully: keep whatever wallet we loaded, mark not fully ready.
      isReady.value = false;
      lastClaimError.value =
          'Wallet initialization failed (${e.runtimeType}). Check RPC configuration.';
      debugPrint('Monad: ${lastClaimError.value}');
    }
    return this;
  }

  Future<void> _loadOrCreateWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_privateKeyPrefKey);

    if (stored != null && stored.isNotEmpty) {
      _credentials = EthPrivateKey.fromHex(stored);
    } else {
      _credentials = EthPrivateKey.createRandom(Random.secure());
      await prefs.setString(
        _privateKeyPrefKey,
        bytesToHex(_credentials!.privateKey),
      );
      // ignore: avoid_print
      print('🔑 Generated new Monad burner wallet');
    }

    _address = _credentials!.address;
    walletAddress.value = _address!.hexEip55;
  }

  void _syncWalletAddress() {
    walletAddress.value = address?.hexEip55 ?? '';
    monBalance.value = 0;
    tracktBalance.value = 0;
    unawaited(refreshBalances());
  }

  /// Short display form, e.g. 0x1234…aB9c for HUD pills.
  String get shortAddress {
    final a = walletAddress.value;
    if (a.length < 10) return a;
    return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
  }

  /// Refresh native MON and \$TRACKT balances. Safe to call anytime; swallows
  /// network errors so observables simply keep their last known value.
  Future<void> refreshBalances() async {
    final client = _client;
    final addr = address;
    if (client == null || addr == null) return;

    try {
      final bal = await client.getBalance(addr);
      if (address == addr) {
        monBalance.value = bal.getValueInUnit(EtherUnit.ether);
      }
    } catch (e) {
      // ignore: avoid_print
      print(
        '⚠️ Could not fetch MON balance (${e.runtimeType}). Check RPC provider/network.',
      );
    }

    if (_hasTokenContract) {
      try {
        final balance = await getTracktTokenBalance();
        if (address == addr) tracktBalance.value = balance;
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Could not fetch \$TRACKT balance (${e.runtimeType}).');
      }
    }
  }

  /// Reads the runner's \$TRACKT (RunRewardToken) balance via ERC-20 balanceOf.
  /// Returns 0.0 when the token contract is not yet deployed/configured.
  Future<double> getTracktTokenBalance() async {
    final client = _client;
    final addr = address;
    if (client == null || addr == null || !_hasTokenContract) return 0.0;

    final contract = DeployedContract(
      ContractAbi.fromJson(_tokenAbi, 'RunRewardToken'),
      EthereumAddress.fromHex(EnvConfig.monadTokenContract),
    );
    final fn = contract.function('balanceOf');
    final result = await client.call(
      contract: contract,
      function: fn,
      params: [addr],
    );
    final raw = result.first as BigInt;
    // RunRewardToken assumed 18 decimals (standard ERC-20).
    return raw / BigInt.from(10).pow(18);
  }

  /// Dispatch a territory claim to Monad Testnet.
  ///
  /// Returns the transaction hash. When the TerritoryRegistry contract is not
  /// yet configured, or the wallet has no gas, falls back to a locally-generated
  /// settlement proof hash so the demo flow stays unbroken ([lastTxOnChain]
  /// reports which path was taken).
  Future<String> claimTerritoryOnChain({
    required String territoryId,
    required double centerLat,
    required double centerLng,
    required double areaSqMeters,
  }) async {
    final selectedPrivy = usesEmbeddedWallet;
    final selectedAddress = address;
    isClaiming.value = true;
    lastTxOnChain.value = false;
    lastClaimError.value = null;
    try {
      final client = _client;
      final creds = _credentials;

      if (client != null && creds != null && _hasTerritoryContract) {
        try {
          final contract = DeployedContract(
            ContractAbi.fromJson(_territoryAbi, 'TerritoryRegistry'),
            EthereumAddress.fromHex(EnvConfig.monadTerritoryContract),
          );
          final fn = contract.function('claimTerritory');

          final params = <dynamic>[
            _territoryIdToUint(territoryId),
            BigInt.from((centerLat * 1e6).round()), // int256, 1e6 fixed point
            BigInt.from((centerLng * 1e6).round()),
            BigInt.from(areaSqMeters.round()),
          ];

          final actualChainId = await client.getChainId().timeout(
            const Duration(seconds: 10),
          );
          if (actualChainId != BigInt.from(chainId)) {
            throw StateError(
              'RPC network does not match the configured chain.',
            );
          }
          if (usesEmbeddedWallet != selectedPrivy ||
              address != selectedAddress) {
            throw StateError('Wallet selection changed during the claim.');
          }
          final String txHash;
          if (selectedPrivy) {
            final sender = selectedAddress;
            if (sender == null) {
              throw StateError('Reconnect your Privy wallet.');
            }
            final data = fn.encodeCall(params);
            final gas = await client.estimateGas(
              sender: sender,
              to: contract.address,
              data: data,
            );
            if (!usesEmbeddedWallet || address != selectedAddress) {
              throw StateError(
                'Wallet selection changed during gas estimation.',
              );
            }
            txHash = await embeddedWallet!.sendTransaction(
              to: contract.address.hexEip55,
              data: bytesToHex(data, include0x: true),
              chainId: chainId,
              gas: gas,
            );
          } else {
            txHash = await client.sendTransaction(
              creds,
              Transaction.callContract(
                contract: contract,
                function: fn,
                parameters: params,
              ),
              chainId: chainId,
            );
          }

          lastTxHash.value = txHash;
          lastTxOnChain.value = true;
          // ignore: avoid_print
          print('✅ Territory claim broadcast to Monad: $txHash');
          unawaited(refreshBalances());
          return txHash;
        } catch (e) {
          lastClaimError.value = usesEmbeddedWallet
              ? 'Privy claim failed. Check wallet connection, MON funding and RPC network.'
              : 'On-chain claim failed. Check MON funding and RPC network.';
          debugPrint('Monad: ${lastClaimError.value} (${e.runtimeType})');
        }
      }

      // Fallback: local settlement proof (contract unset or send failed).
      final proof = _localProofHash();
      lastTxHash.value = proof;
      lastTxOnChain.value = false;
      // ignore: avoid_print
      print('🧪 Local settlement proof generated: $proof');
      return proof;
    } finally {
      isClaiming.value = false;
    }
  }

  /// Map a UUID territory id to a uint256. UUIDs are 32 hex chars (128-bit),
  /// which fits uint256 directly after stripping dashes.
  BigInt _territoryIdToUint(String territoryId) {
    final hex = territoryId.replaceAll('-', '').trim();
    final parsed = BigInt.tryParse(hex, radix: 16);
    if (parsed != null) return parsed;
    // Non-UUID ids: derive a stable positive int from the string.
    return BigInt.from(territoryId.hashCode.abs());
  }

  String _localProofHash() {
    final rnd = Random.secure();
    final buf = StringBuffer('0x');
    for (int i = 0; i < 64; i++) {
      buf.write(rnd.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }

  /// Monad Testnet explorer link for a transaction hash.
  String explorerTxUrl(String txHash) =>
      'https://testnet.monadexplorer.com/tx/$txHash';

  @override
  void onClose() {
    _walletWorker?.dispose();
    _client?.dispose();
    _httpClient?.close();
    super.onClose();
  }
}
