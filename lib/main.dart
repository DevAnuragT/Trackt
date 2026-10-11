import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_colors.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
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
import 'services/seed_territory_service.dart';
import 'services/user_preferences_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/samsung_permission_helper.dart';
import 'services/simulation_service.dart';
import 'services/monad_service.dart';
import 'services/power_up_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await EnvConfig.load();
  
  // Initialize Mapbox with access token
  try {
    if (MapboxConfig.isConfigured) {
      mapbox.MapboxOptions.setAccessToken(MapboxConfig.accessToken);
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
    Get.put(SeedTerritoryService());
    Get.put(TerritoryService());
    Get.put(AuthController());
    Get.put(DatabaseService());
    Get.put(NotificationService());
    Get.put(SamsungPermissionHelper());
    // Initialize UserPreferencesService asynchronously
    await Get.putAsync(() => UserPreferencesService().init());
    await Get.putAsync(() => PowerUpService().init());
    await Get.putAsync(() => MonadService().init());
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
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _tracktTheme,
      darkTheme: _tracktTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) => AppRoutes.generateRoute(settings),
    );
  }

  /// Flat, modern, minimal dark theme: neutral surfaces, one emerald accent,
  /// no gradients, no glows. Tokens live in [AppColors].
  static final ThemeData _tracktTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceVariant,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.surfaceVariant,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.accent,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}
