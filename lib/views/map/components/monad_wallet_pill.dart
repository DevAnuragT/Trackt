import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/monad_service.dart';

/// Compact glassmorphic HUD pill showing the local Monad burner wallet.
/// Tapping opens a details sheet with the full address, balances, and links.
/// Renders nothing if MonadService isn't registered (e.g. in minimal tests).
class MonadWalletPill extends StatelessWidget {
  const MonadWalletPill({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MonadService>()) return const SizedBox.shrink();
    final monad = Get.find<MonadService>();

    return InkWell(
      onTap: () => _showWalletSheet(context, monad),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF17171A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2F)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet, color: Color(0xFF6366F1), size: 15),
            const SizedBox(width: 6),
            Obx(() => Text(
                  monad.walletAddress.value.isEmpty ? 'Wallet' : monad.shortAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                )),
            const SizedBox(width: 8),
            Obx(() => Text(
                  '${monad.tracktBalance.value.toStringAsFixed(0)} \$TRACKT',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showWalletSheet(BuildContext context, MonadService monad) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF17171A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF6366F1), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Monad Session Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Chain ${monad.chainId}',
                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row('Address', monad.walletAddress.value, copyable: true),
            const SizedBox(height: 10),
            Obx(() => _row('MON (gas)', monad.monBalance.value.toStringAsFixed(5))),
            const SizedBox(height: 10),
            Obx(() => _row('\$TRACKT', monad.tracktBalance.value.toStringAsFixed(0))),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showReceiveSheet(monad),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Add MON'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _openAddressExplorer(monad),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Explorer'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'On-device burner wallet. Runs settle in the background — gas is tiny on Monad. Top up MON if your balance runs low.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyable)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              Get.snackbar(
                'Copied',
                'Wallet address copied to clipboard',
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF6366F1),
                colorText: Colors.white,
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, color: Color(0xFF6366F1), size: 15),
            ),
          ),
      ],
    );
  }

  /// Receive/top-up sheet: QR of the burner address + copy + faucet link, so a
  /// user can fund their wallet with testnet MON from the Monad faucet or
  /// another wallet. (Real runs settle fine on the local proof when unfunded.)
  void _showReceiveSheet(MonadService monad) {
    final address = monad.walletAddress.value;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF17171A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add MON to your wallet',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send Monad Testnet MON to this address (faucet or another wallet).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: address,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF202024),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: address));
                      Get.snackbar('Copied', 'Wallet address copied',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFF202024),
                          colorText: Colors.white);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, color: Color(0xFF6366F1), size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _open('https://faucet.monad.xyz'),
                icon: const Icon(Icons.water_drop_outlined, size: 18),
                label: const Text('Open Monad Faucet'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Clipboard.setData(ClipboardData(text: url));
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: url));
    }
  }

  Future<void> _openAddressExplorer(MonadService monad) async {
    final url = 'https://testnet.monadexplorer.com/address/${monad.walletAddress.value}';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Clipboard.setData(ClipboardData(text: url));
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: url));
    }
  }
}
