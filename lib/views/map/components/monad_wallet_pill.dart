import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
          color: const Color(0xFF17171A).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.7),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.22),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
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
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _openAddressExplorer(monad),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View on Monad Explorer'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Burner wallet generated on-device. Gasless-feeling: no popups mid-run.',
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
