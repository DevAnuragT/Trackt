import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/monad_service.dart';
import '../../../controllers/auth/auth_controller.dart';
import '../../../services/on_chain_leaderboard_service.dart';
import '../../on_chain_leaderboard_page.dart';
import 'embedded_wallet_sheet.dart';

/// Compact wallet HUD using the app's shared flat theme.
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              color: AppColors.accent,
              size: 15,
            ),
            const SizedBox(width: 6),
            Obx(
              () => Text(
                monad.walletAddress.value.isEmpty
                    ? 'Wallet'
                    : monad.shortAddress,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(
              () => Text(
                '${monad.tracktBalance.value.toStringAsFixed(0)} \$TRACKT',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletSheet(BuildContext context, MonadService monad) {
    Get.bottomSheet(
      SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.accent, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      monad.usesEmbeddedWallet
                          ? 'Privy Embedded Wallet'
                          : 'Monad Session Wallet',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Chain ${monad.chainId}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Obx(
                () =>
                    _row('Address', monad.walletAddress.value, copyable: true),
              ),
              const SizedBox(height: 10),
              Obx(
                () => _row(
                  'MON (gas)',
                  monad.monBalance.value.toStringAsFixed(5),
                ),
              ),
              const SizedBox(height: 10),
              Obx(
                () => _row(
                  '\$TRACKT',
                  monad.tracktBalance.value.toStringAsFixed(0),
                ),
              ),
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
              Obx(() {
                final message = monad.lastClaimError.value;
                return message == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      );
              }),
              if (monad.embeddedWallet != null) ...[
                Obx(
                  () => Text(
                    monad.embeddedWallet!.error.value ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final service = monad.embeddedWallet!;
                      if (service.isSelected.value) {
                        await service.useBurner();
                        Get.back();
                      } else if (!service.isConfigured) {
                        Get.snackbar(
                          'Privy setup needed',
                          'Set PRIVY_APP_ID and PRIVY_CLIENT_ID in the local configuration.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        final email = Get.isRegistered<AuthController>()
                            ? Get.find<AuthController>().user?.email
                            : null;
                        if (email == null || email.isEmpty) {
                          Get.snackbar(
                            'Sign in first',
                            'Sign in to Trackt before connecting Privy.',
                          );
                          return;
                        }
                        Get.back();
                        Get.bottomSheet(
                          EmbeddedWalletSheet(service: service, email: email),
                          isScrollControlled: true,
                        );
                      }
                    },
                    child: Text(
                      monad.usesEmbeddedWallet
                          ? 'Use preserved burner wallet'
                          : 'Connect Privy wallet',
                    ),
                  ),
                ),
                if (monad.usesEmbeddedWallet)
                  _row('Burner saved', monad.burnerAddress, copyable: true),
                const SizedBox(height: 8),
              ],
              if (Get.isRegistered<OnChainLeaderboardService>())
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                      Get.to(
                        () => OnChainLeaderboardPage(
                          service: Get.find<OnChainLeaderboardService>(),
                        ),
                      );
                    },
                    child: const Text('On-chain standings'),
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'Wallets are separate. Funds are never moved automatically. '
                'Top up the selected address with Testnet MON to broadcast claims.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _row(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyable && value.isNotEmpty)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              Get.snackbar(
                'Copied',
                'Wallet address copied to clipboard',
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.accent,
                colorText: AppColors.textPrimary,
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, color: AppColors.accent, size: 15),
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
    if (address.isEmpty) {
      Get.snackbar(
        'Wallet unavailable',
        'Reconnect your selected wallet before funding it.',
      );
      return;
    }
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add MON to your wallet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send Monad Testnet MON to this address (faucet or another wallet).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: address));
                      Get.snackbar(
                        'Copied',
                        'Wallet address copied',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.surfaceVariant,
                        colorText: AppColors.textPrimary,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        color: AppColors.accent,
                        size: 16,
                      ),
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
    if (monad.walletAddress.value.isEmpty) {
      Get.snackbar(
        'Wallet unavailable',
        'Reconnect your selected wallet first.',
      );
      return;
    }
    final url =
        'https://testnet.monadexplorer.com/address/${monad.walletAddress.value}';
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
