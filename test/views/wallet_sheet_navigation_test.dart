import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/embedded_wallet_service.dart';
import 'package:trackt/services/monad_service.dart';
import 'package:trackt/services/on_chain_leaderboard_service.dart';
import 'package:trackt/views/map/components/embedded_wallet_sheet.dart';
import 'package:trackt/views/map/components/monad_wallet_pill.dart';
import 'package:trackt/views/on_chain_leaderboard_page.dart';

class _Embedded extends EmbeddedWalletService {
  _Embedded() : super(currentAccountId: () => 'account') {
    isSelected.value = true;
    walletAddress.value = '0x1111111111111111111111111111111111111111';
  }

  @override
  Future<void> useBurner() async {
    isSelected.value = false;
  }

  @override
  bool get hasSession => true;

  @override
  Future<void> activateExistingSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });
  tearDown(Get.reset);

  testWidgets(
    'standings opens after closing wallet and back does not expose a stale sheet',
    (tester) async {
      final monad = await Get.putAsync(() => MonadService().init());
      Get.put(
        OnChainLeaderboardService(
          endpoint: 'https://indexer.example/graphql',
          client: MockClient(
            (_) async => http.Response('{"data":{"Player":[]}}', 200),
          ),
        ),
      );
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: MonadWalletPill())),
      );
      await tester.tap(find.text(monad.shortAddress));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('On-chain standings'));
      await tester.tap(find.text('On-chain standings'));
      await tester.pumpAndSettle();
      expect(find.byType(OnChainLeaderboardPage), findsOneWidget);
      expect(find.text('Monad Session Wallet'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Monad Session Wallet'), findsNothing);
      expect(find.text(monad.shortAddress), findsOneWidget);
    },
  );

  testWidgets(
    'switching to the burner closes exactly the selected wallet sheet',
    (tester) async {
      final embedded = _Embedded();
      final monad = await Get.putAsync(
        () => MonadService(embeddedWallet: embedded).init(),
      );
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: MonadWalletPill())),
      );
      await tester.tap(find.text(monad.shortAddress));
      await tester.pumpAndSettle();
      expect(find.text('Privy Embedded Wallet'), findsOneWidget);
      await tester.ensureVisible(find.text('Use preserved burner wallet'));
      await tester.tap(find.text('Use preserved burner wallet'));
      await tester.pumpAndSettle();
      expect(embedded.isSelected.value, false);
      expect(find.byType(BottomSheet), findsNothing);
      expect(monad.walletAddress.value, monad.burnerAddress);
    },
  );

  testWidgets(
    'successful existing Privy session closes its actual Flutter modal route',
    (tester) async {
      final embedded = _Embedded();
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EmbeddedWalletSheet(
                    service: embedded,
                    email: 'test@example.invalid',
                  ),
                ),
                child: const Text('Connect'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Privy wallet'));
      await tester.pumpAndSettle();
      expect(find.byType(EmbeddedWalletSheet), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
    },
  );
}
