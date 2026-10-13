import 'package:get/get.dart';
import '../services/daily_challenge_service.dart';

class MainNavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTab(int index) {
    currentIndex.value = index;
    if (index == 2 && Get.isRegistered<DailyChallengeService>()) {
      Get.find<DailyChallengeService>().refreshFromServer(force: true);
    }
  }

  // Navigation methods
  void goToWorld() => currentIndex.value = 0;
  void goToClub() => currentIndex.value = 1;
  void goToDailyQuests() => changeTab(2);
  void goToStore() => currentIndex.value = 3;
  void goToProfile() => currentIndex.value = 4;
}
