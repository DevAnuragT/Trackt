import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'services/env_config.dart';
import 'routes/app_routes.dart';
import 'controllers/auth/auth_controller.dart';
import 'controllers/map/run_tracker_controller.dart';
import 'services/mapbox_config.dart';
import 'services/location_service.dart';
import 'services/location_permission_service.dart';
import 'services/run_storage_service.dart';
import 'services/run_history_service.dart';
import 'services/territory_service.dart';
import 'services/user_preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/samsung_permission_helper.dart';
import 'services/simulation_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await EnvConfig.load();
  
  // Initialize Mapbox with access token
  try {
    if (MapboxConfig.isConfigured) {
      MapboxOptions.setAccessToken(MapboxConfig.accessToken);
      print('Mapbox initialized successfully in main()');
    } else {
      print('Warning: Mapbox access token not configured');
    }
  } catch (e) {
    print('Mapbox initialization error in main(): $e');
  }
  
  // Initialize Supabase if configured
  final supaUrl = EnvConfig.supabaseUrl;
  final supaKey = EnvConfig.supabaseAnonKey;
  if (supaUrl != null && supaUrl.isNotEmpty && supaKey != null && supaKey.isNotEmpty) {
    await Supabase.initialize(
      url: supaUrl, 
      anonKey: supaKey,
    );
    
    print('✅ Supabase initialized with default session persistence');
  }
  
  // Initialize GetX controllers with error handling
  try {
    // Initialize core services
    Get.put(LocationService(), permanent: true);
    Get.put(LocationPermissionService(), permanent: true);
    Get.put(RunStorageService());
    Get.put(TerritoryHistoryService());
    Get.put(TerritoryService());
    Get.put(AuthController());
    Get.put(DatabaseService());
    Get.put(NotificationService());
    Get.put(SamsungPermissionHelper());
    // Initialize UserPreferencesService asynchronously
    await Get.putAsync(() => UserPreferencesService().init());
    Get.put(RunTrackerController());
    Get.put(SimulationService(), permanent: true);
    
    // REMOVED: Location permissions are now requested after UI is ready
    // This prevents black screen issues during app startup
    
    // Ensure user profile exists if user is authenticated
    try {
      final databaseService = Get.find<DatabaseService>();
      if (databaseService.isAuthenticated) {
        print('🔍 Ensuring user profile exists on app start...');
        await databaseService.ensureUserProfileExists();
        print('✅ User profile ensured on app start');
        
        // Also refresh the user preferences service
        try {
          final prefsService = Get.find<UserPreferencesService>();
          await prefsService.refreshProfileFromSupabase();
          print('✅ User preferences refreshed from Supabase on app start');
        } catch (e) {
          print('⚠️ Could not refresh user preferences on app start: $e');
        }
      } else {
        print('ℹ️ No authenticated user on app start');
      }
    } catch (e) {
      print('⚠️ Could not ensure user profile on app start: $e');
    }
  } catch (e) {
    print('Error initializing controllers: $e');
    // Continue with basic initialization
    Get.put(AuthController());
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
              title: 'Trackt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) => AppRoutes.generateRoute(settings),
    );
  }
}
