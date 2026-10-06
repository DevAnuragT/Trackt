import 'package:get/get.dart';

class MainNavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;

  void changeTab(int index) {
    currentIndex.value = index;
  }

  // Navigation methods
  void goToWorld() => currentIndex.value = 0;
  void goToClub() => currentIndex.value = 1;
  void goToDailyQuests() => currentIndex.value = 2;
  void goToProfile() => currentIndex.value = 3;
}
