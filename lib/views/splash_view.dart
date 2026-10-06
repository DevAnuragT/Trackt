import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_preferences_service.dart';
import '../services/location_permission_service.dart'; // Added import for LocationPermissionService

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Brief splash
    
    if (mounted) {
      try {
        print('🔍 Starting auth status check...');
        
        // Ensure UserPreferencesService is initialized first
        UserPreferencesService prefs;
        try {
          prefs = Get.find<UserPreferencesService>();
          print('✅ UserPreferencesService found');
        } catch (e) {
          print('⚠️ UserPreferencesService not found, initializing...');
          prefs = await Get.putAsync(() => UserPreferencesService().init());
          print('✅ UserPreferencesService initialized');
        }
        
        // Check if user is authenticated with Supabase
        final user = Supabase.instance.client.auth.currentUser;
        final session = Supabase.instance.client.auth.currentSession;
        
        print('🔍 Auth check - User: ${user?.id}, Session: ${session?.accessToken != null ? "valid" : "invalid"}');
        print('🔍 First launch: ${prefs.isFirstLaunch.value}, Has setup: ${prefs.hasCompletedSetup}');
        
        if (user != null && session != null) {
          // Check if session is expired
          if (session.expiresAt != null) {
            final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt!);
            if (DateTime.now().isAfter(expiresAt)) {
              print('⚠️ Session expired, attempting to refresh...');
              try {
                await Supabase.instance.client.auth.refreshSession();
                print('✅ Session refreshed successfully');
              } catch (e) {
                print('❌ Failed to refresh session: $e');
                // Session refresh failed, go to sign in
                Get.offAllNamed('/signin');
                return;
              }
            }
          }
          
          // User is authenticated, check if setup is completed
          // Check local preferences first (more reliable)
          if (prefs.hasCompletedSetup) {
            // User has completed setup locally, go directly to home
            print('✅ User authenticated and setup completed locally, going to home');
            Get.offAllNamed('/home');
          } else {
            // Check Supabase metadata as fallback
            if (user.userMetadata?['username'] != null && 
                (user.userMetadata?['username'] as String).isNotEmpty) {
              print('✅ User authenticated and setup completed in Supabase, going to home');
              Get.offAllNamed('/home');
            } else {
              // User is authenticated but needs to complete setup
              print('⚠️ User authenticated but setup not completed, going to setup');
              Get.offAllNamed('/setup');
            }
          }
        } else {
          // Check if this is first launch
          if (prefs.isFirstLaunch.value) {
            // First time user, show intro
            print('🆕 First time user, showing intro');
            Get.offAllNamed('/intro');
          } else {
            // Check if this is a fresh app install (no username, not first launch)
            if (prefs.isFreshAppInstall) {
              print('🆕 Fresh app install detected, resetting to first launch state');
              await prefs.resetToFirstLaunch();
              Get.offAllNamed('/intro');
            } else {
              // Returning user but not authenticated, go to sign in
              print('🔐 Returning user not authenticated, going to sign in');
              Get.offAllNamed('/signin');
            }
          }
        }
        
        // Request location permissions after navigation is complete
        // This prevents black screen issues during app startup
        _requestLocationPermissionsAfterNavigation();
        
      } catch (e) {
        print('❌ Error checking auth status: $e');
        // On error, try to show intro as a fallback
        try {
          final prefs = await Get.putAsync(() => UserPreferencesService().init());
          if (prefs.isFirstLaunch.value) {
            Get.offAllNamed('/intro');
          } else {
            Get.offAllNamed('/signin');
          }
        } catch (_) {
          // Last resort: go to intro
          Get.offAllNamed('/intro');
        }
        
        // Request location permissions after navigation is complete
        _requestLocationPermissionsAfterNavigation();
      }
    }
  }
  
  /// Request location permissions after navigation is complete
  /// This prevents black screen issues during app startup
  Future<void> _requestLocationPermissionsAfterNavigation() async {
    try {
      // Wait a bit for navigation to complete
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (mounted) {
        print('🔍 Requesting location permissions after navigation...');
        try {
          final permissionService = Get.find<LocationPermissionService>();
          await permissionService.smartCheckLocationPermissions();
          print('✅ Location permissions handled after navigation');
        } catch (e) {
          print('⚠️ Error handling location permissions after navigation: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error in _requestLocationPermissionsAfterNavigation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf7f5f0), // Match Android launch background color
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFf7f5f0), // Consistent background color
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive image size based on screen dimensions
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;
                final imageSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.6;
                
                return Image.asset(
                  'assets/splash.png',
                  width: imageSize.clamp(200.0, 400.0), // Min 200, Max 400
                  height: imageSize.clamp(200.0, 400.0),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFf7f5f0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 100,
                        color: Colors.grey,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
