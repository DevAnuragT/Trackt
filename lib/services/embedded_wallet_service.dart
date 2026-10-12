import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env_config.dart';

class EmbeddedWalletService extends GetxService with WidgetsBindingObserver {
  static const selectedPreference = 'trackt_privy_selected';
  static const accountPreference = 'trackt_privy_account';
  final String? Function() currentAccountId;
  final String? _appId;
  final String? _clientId;
  Privy? _sdk;
  EmbeddedEthereumWallet? _wallet;
  final isSelected = false.obs;
  final walletAddress = ''.obs;
  final error = RxnString();

  EmbeddedWalletService({
    required this.currentAccountId,
    Privy? sdk,
    String? appId,
    String? clientId,
  }) : _sdk = sdk,
       _appId = appId,
       _clientId = clientId;

  bool get isConfigured =>
      (_appId ?? EnvConfig.privyAppId).isNotEmpty &&
      (_clientId ?? EnvConfig.privyClientId).isNotEmpty;

  bool get hasSession => _sdk?.currentAuthState.isAuthenticated ?? false;

  Future<EmbeddedWalletService> init() async {
    final prefs = await SharedPreferences.getInstance();
    isSelected.value =
        prefs.getBool(selectedPreference) == true &&
        prefs.getString(accountPreference) == currentAccountId() &&
        currentAccountId() != null;
    if (!isConfigured) {
      _report('Privy App ID and mobile Client ID are required.');
      return this;
    }
    _sdk ??= Privy.init(
      config: PrivyConfig(
        appId: _appId ?? EnvConfig.privyAppId,
        appClientId: _clientId ?? EnvConfig.privyClientId,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(restoreSession());
    return this;
  }

  Future<void> restoreSession() async {
    if (_sdk == null || !isSelected.value) return;
    final prefs = await SharedPreferences.getInstance();
    final boundAccount = prefs.getString(accountPreference);
    if (boundAccount != currentAccountId() || currentAccountId() == null) {
      _wallet = null;
      walletAddress.value = '';
      _report('The Trackt account changed. Reconnect your selected wallet.');
      return;
    }
    try {
      if (_sdk!.currentAuthState is AuthenticatedUnverified) {
        await _sdk!.onNetworkRestored().timeout(const Duration(seconds: 12));
      }
      final state = await _sdk!.getAuthState().timeout(
        const Duration(seconds: 12),
      );
      if (state is Authenticated) {
        await _loadWallet(state.user);
        if (currentAccountId() != boundAccount) {
          _wallet = null;
          walletAddress.value = '';
          _report(
            'The Trackt account changed. Reconnect your selected wallet.',
          );
          return;
        }
        error.value = null;
      } else {
        _wallet = null;
        walletAddress.value = '';
        _report(
          'Reconnect your Privy wallet. The burner has not been selected.',
        );
      }
    } on PrivyException catch (exception) {
      _report(exception.message);
    } on PlatformException {
      _report('The embedded-wallet SDK could not restore its session.');
    } on TimeoutException {
      _report('Privy session restoration timed out. Reconnect when online.');
    }
  }

  Future<void> sendEmailCode(String email) async {
    if (_sdk == null) throw StateError('Configure the Privy mobile Client ID.');
    if (currentAccountId() == null) {
      throw StateError('Sign in to Trackt first.');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError('Your account needs an email.');
    }
    _unwrap(await _sdk!.email.sendCode(email.trim()));
  }

  Future<void> verifyEmailCode(String email, String code) async {
    if (_sdk == null) throw StateError('Configure the Privy mobile Client ID.');
    final account = currentAccountId();
    if (account == null) {
      throw StateError('Sign in to Trackt first.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw ArgumentError('Enter the six-digit verification code.');
    }
    final user = _unwrap(
      await _sdk!.email.loginWithCode(email: email.trim(), code: code.trim()),
    );
    await _activate(user, account);
  }

  Future<void> activateExistingSession() async {
    if (_sdk == null) throw StateError('Configure the Privy mobile Client ID.');
    final account = currentAccountId();
    if (account == null) throw StateError('Sign in to Trackt first.');
    final state = await _sdk!.getAuthState();
    if (state is! Authenticated) {
      throw StateError('Reconnect your Privy wallet.');
    }
    await _activate(state.user, account);
  }

  Future<void> _activate(PrivyUser user, String account) async {
    await _loadWallet(user);
    if (currentAccountId() != account) {
      _wallet = null;
      walletAddress.value = '';
      throw StateError('The Trackt account changed. Reconnect your wallet.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accountPreference, account);
    await prefs.setBool(selectedPreference, true);
    isSelected.value = true;
    error.value = null;
  }

  Future<void> _loadWallet(PrivyUser user) async {
    _wallet = user.embeddedEthereumWallets.isNotEmpty
        ? user.embeddedEthereumWallets.first
        : _unwrap(await user.createEthereumWallet());
    walletAddress.value = _wallet!.address;
  }

  Future<void> useBurner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(selectedPreference, false);
    await prefs.remove(accountPreference);
    isSelected.value = false;
    error.value = null;
  }

  Future<void> disconnectOnSignOut() async {
    if (_sdk != null) await _sdk!.logout();
    await useBurner();
    _wallet = null;
    walletAddress.value = '';
  }

  Future<String> sendTransaction({
    required String to,
    required String data,
    required int chainId,
    required BigInt gas,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final wallet = _wallet;
    final account = prefs.getString(accountPreference);
    if (!isSelected.value ||
        wallet == null ||
        _sdk == null ||
        account != currentAccountId()) {
      throw StateError('Reconnect the selected Privy wallet before claiming.');
    }
    final state = await _sdk!.getAuthState();
    if (!isSelected.value ||
        _wallet != wallet ||
        currentAccountId() != account ||
        state is! Authenticated ||
        !state.user.embeddedEthereumWallets.any(
          (available) =>
              available.address.toLowerCase() == wallet.address.toLowerCase(),
        )) {
      throw StateError('The Privy wallet session is not verified.');
    }
    final response = _unwrap(
      await wallet.provider.request(
        EthereumRpcRequest.ethSendTransaction(
          jsonEncode({
            'from': wallet.address,
            'to': to,
            'data': data,
            'chainId': '0x${chainId.toRadixString(16)}',
            'gas': '0x${gas.toRadixString(16)}',
            'value': '0x0',
          }),
        ),
      ),
    );
    final raw = response.data;
    final decoded = raw.startsWith('"') ? jsonDecode(raw) : raw;
    if (decoded is! String ||
        !RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(decoded)) {
      throw const FormatException(
        'Privy returned an invalid transaction hash.',
      );
    }
    return decoded;
  }

  T _unwrap<T>(Result<T> result) => switch (result) {
    Success<T>(:final value) => value,
    Failure<T>(:final error) => throw error,
  };

  void _report(String message) {
    error.value = message;
    debugPrint('Privy: $message');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(restoreSession());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
