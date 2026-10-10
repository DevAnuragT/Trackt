import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackt/services/power_up_service.dart';
import 'package:trackt/services/user_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  test('rewardMultiplier is 1 by default, 2 while Speed Multiplier active', () async {
    SharedPreferences.setMockInitialValues({'userCoins': 1000});
    await Get.putAsync(() => UserPreferencesService().init());
    final shop = await Get.putAsync(() => PowerUpService().init());

    expect(shop.rewardMultiplier, 1);

    final speed = shop.itemById('speed')!;
    expect(await shop.purchase(speed), PurchaseResult.success);
    expect(shop.rewardMultiplier, 2);
  });

  test('other power-ups do not change the reward multiplier', () async {
    SharedPreferences.setMockInitialValues({'userCoins': 1000});
    await Get.putAsync(() => UserPreferencesService().init());
    final shop = await Get.putAsync(() => PowerUpService().init());

    await shop.purchase(shop.itemById('shield')!);
    expect(shop.rewardMultiplier, 1);
  });
}
