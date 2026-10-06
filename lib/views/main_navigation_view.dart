import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/main_navigation_controller.dart';
import '../services/territory_service.dart';
import '../services/run_history_service.dart';
import '../views/map/components/bottom_sheet_widget.dart';
import 'map/map_view.dart';
import 'club/club_view.dart';
import 'daily_quests/daily_quests_view.dart';
import 'profile_view.dart';
import '../services/location_permission_service.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Force refresh all user data when reaching home screen
    _refreshAllUserDataOnHomeScreen();
    // Ensure landing tab is Map (index 0)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<MainNavigationController>()) {
        final c = Get.find<MainNavigationController>();
        c.changeTab(0);
      }
    });
  }
  
  /// Force refresh all user data when reaching home screen
  /// This ensures fresh data is loaded after authentication
  Future<void> _refreshAllUserDataOnHomeScreen() async {
    try {
      print('🔄 Force refreshing all user data on home screen...');
      
      // Small delay to ensure all controllers are initialized
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 1. Refresh territory data
      if (Get.isRegistered<TerritoryService>()) {
        final territoryService = Get.find<TerritoryService>();
        await territoryService.refreshNearbyTerritories();
        await territoryService.fetchUserTerritories();
        print('✅ Territory data refreshed on home screen');
      }
      
      // 2. Refresh territory history
      if (Get.isRegistered<TerritoryHistoryService>()) {
        final historyService = Get.find<TerritoryHistoryService>();
        await historyService.loadTerritories();
        print('✅ Territory history refreshed on home screen');
      }
      
      // 3. Refresh bottom sheet statistics
      if (Get.isRegistered<BottomSheetController>()) {
        final bottomSheetController = Get.find<BottomSheetController>();
        await bottomSheetController.loadUserStatistics();
        print('✅ Bottom sheet statistics refreshed on home screen');
      }
      
      // 4. Handle location permissions now that the UI is ready
      _handleLocationPermissionsOnHomeScreen();
      
      print('✅ All user data refreshed successfully on home screen');
      
    } catch (e) {
      print('⚠️ Error refreshing user data on home screen: $e');
      // Don't throw - this is not critical for the UI to work
    }
  }
  
  /// Handle location permissions when the user reaches the home screen
  /// This ensures permissions are requested at the right time
  Future<void> _handleLocationPermissionsOnHomeScreen() async {
    try {
      print('🔍 Handling location permissions on home screen...');
      
      // Wait a bit more to ensure the UI is fully ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        try {
          final permissionService = Get.find<LocationPermissionService>();
          await permissionService.smartCheckLocationPermissions();
          print('✅ Location permissions handled on home screen');
        } catch (e) {
          print('⚠️ Error handling location permissions on home screen: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error in _handleLocationPermissionsOnHomeScreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MainNavigationController());

    return Scaffold(
      body: Obx(() => IndexedStack(
        index: controller.currentIndex.value,
        children: [
          const MapView(),           // World tab
          const ClubView(),          // Club tab
          const DailyQuestsView(),   // Daily Quests tab
          const ProfileView(),       // Profile tab
        ],
      )),
      bottomNavigationBar: Obx(() => BottomNavigationBar(
        currentIndex: controller.currentIndex.value,
        onTap: controller.changeTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'World',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Club',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Quests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      )),
    );
  }
}
