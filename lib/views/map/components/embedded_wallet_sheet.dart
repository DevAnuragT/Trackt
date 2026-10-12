import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/embedded_wallet_service.dart';

class EmbeddedWalletSheet extends StatefulWidget {
  final EmbeddedWalletService service;
  final String email;

  const EmbeddedWalletSheet({
    super.key,
    required this.service,
    required this.email,
  });

  @override
  State<EmbeddedWalletSheet> createState() => _EmbeddedWalletSheetState();
}

class _EmbeddedWalletSheetState extends State<EmbeddedWalletSheet> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_sent) {
        await widget.service.verifyEmailCode(widget.email, _code.text);
        if (mounted) Get.back();
      } else if (widget.service.hasSession) {
        await widget.service.activateExistingSession();
        if (mounted) Get.back();
      } else {
        await widget.service.sendEmailCode(widget.email);
        if (mounted) setState(() => _sent = true);
      }
    } on PrivyException catch (error) {
      _showError(error.message);
    } on PlatformException {
      _showError('The wallet SDK could not connect. Try again.');
    } on StateError catch (error) {
      _showError(error.message.toString());
    } on ArgumentError catch (error) {
      _showError(error.message.toString());
    } on TimeoutException {
      _showError('Wallet connection timed out. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    debugPrint('Privy wallet connection failed: $message');
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect embedded wallet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Privy creates a separate wallet for your account. Your burner '
                  'wallet and its funds stay intact. Fund the new address with '
                  'Monad Testnet MON before claiming on-chain.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.email, style: const TextStyle(fontSize: 13)),
                if (_sent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Six-digit email code',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Connecting...'
                          : _sent
                          ? 'Verify and use Privy wallet'
                          : widget.service.hasSession
                          ? 'Use Privy wallet'
                          : 'Send verification code',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
