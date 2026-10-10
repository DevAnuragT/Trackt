import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/monad_service.dart';
import 'package:trackt/views/map/components/monad_wallet_pill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('renders nothing when MonadService is not registered', (tester) async {
    Get.reset();
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: MonadWalletPill())),
    );
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('\$TRACKT'), findsNothing);
  });

  testWidgets('shows short address and TRACKT balance when registered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Get.putAsync(() => MonadService().init());

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: MonadWalletPill())),
    );
    await tester.pump();

    expect(find.textContaining('…'), findsOneWidget); // short address
    expect(find.textContaining('\$TRACKT'), findsOneWidget);
  });
}
