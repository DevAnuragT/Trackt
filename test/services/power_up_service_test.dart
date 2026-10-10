import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/power_up_service.dart';
import 'package:trackt/services/user_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  Future<(PowerUpService, UserPreferencesService)> setup(int coins) async {
    SharedPreferences.setMockInitialValues({'userCoins': coins});
    final prefs = await Get.putAsync(() => UserPreferencesService().init());
    final shop = await Get.putAsync(() => PowerUpService().init());
    return (shop, prefs);
  }

  test('catalog has the three power-ups with expected costs', () {
    final ids = PowerUpService.catalog.map((e) => e.id).toSet();
    expect(ids, {'shield', 'speed', 'flag'});
    expect(PowerUpService.catalog.firstWhere((e) => e.id == 'shield').cost, 250);
    expect(PowerUpService.catalog.firstWhere((e) => e.id == 'speed').cost, 150);
    expect(PowerUpService.catalog.firstWhere((e) => e.id == 'flag').cost, 500);
  });

  test('purchase succeeds and debits coins when affordable', () async {
    final (shop, prefs) = await setup(300);
    final shield = shop.itemById('shield')!;

    final result = await shop.purchase(shield);
    expect(result, PurchaseResult.success);
    expect(prefs.userCoins.value, 50); // 300 - 250
    expect(shop.isActive('shield'), isTrue);
    expect(shop.remaining('shield'), isNotNull);
  });

  test('purchase fails with insufficient funds and does not debit', () async {
    final (shop, prefs) = await setup(100);
    final shield = shop.itemById('shield')!;

    final result = await shop.purchase(shield);
    expect(result, PurchaseResult.insufficientFunds);
    expect(prefs.userCoins.value, 100);
    expect(shop.isActive('shield'), isFalse);
  });

  test('permanent item cannot be bought twice', () async {
    final (shop, prefs) = await setup(2000);
    final flag = shop.itemById('flag')!;

    expect(await shop.purchase(flag), PurchaseResult.success);
    expect(shop.isActive('flag'), isTrue);
    expect(shop.remaining('flag'), isNull); // permanent

    expect(await shop.purchase(flag), PurchaseResult.alreadyActive);
    expect(prefs.userCoins.value, 1500); // only charged once
  });

  test('ownership persists across service reloads', () async {
    final (shop, _) = await setup(1000);
    await shop.purchase(shop.itemById('shield')!);

    // Reload a fresh instance from the same prefs.
    final reloaded = await PowerUpService().init();
    expect(reloaded.isActive('shield'), isTrue);
  });
}
