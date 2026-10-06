import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/user_preferences_service.dart';
import '../../services/database_service.dart';
import '../../services/territory_service.dart';
import '../../services/run_history_service.dart';
import '../../views/map/components/bottom_sheet_widget.dart';
import '../../services/run_storage_service.dart';
import '../../services/user_notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/daily_challenge_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  
  // Reactive variables
  final _isLoading = false.obs;
  final _user = Rxn<User>();
  
  // Getters
  bool get isLoading => _isLoading.value;
  User? get user => _user.value;
  bool get isSignedIn => _user.value != null;
  
  @override
  void onInit() {
    super.onInit();
    _initAuthListener();
  }
  
  void _initAuthListener() {
    // Listen to auth state changes
    _user.value = Supabase.instance.client.auth.currentUser;
    print('🔍 Auth listener initialized, current user: ${_user.value?.id ?? 'None'}');
    
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      print('🔄 Auth state change detected: ${data.event}');
      print('🔄 Session user: ${data.session?.user.id ?? 'None'}');
      
      _user.value = data.session?.user;
      
      // If user signed in, refresh their profile from Supabase
      if (data.session?.user != null) {
        try {
          if (Get.isRegistered<UserPreferencesService>()) {
            final prefsService = Get.find<UserPreferencesService>();
            await prefsService.refreshProfileFromSupabase();
            print('✅ User profile refreshed from Supabase after auth state change');
          }
        } catch (e) {
          print('⚠️ Failed to refresh profile after auth state change: $e');
        }
      }
    });
  }
  
  // Check if user needs setup and navigate accordingly
  Future<void> _checkUserSetupAndNavigate() async {
    try {
      // Check if user has a profile in Supabase user_profiles table
      final user = Supabase.instance.client.auth.currentUser;
      print('🔍 _checkUserSetupAndNavigate called, user: ${user?.id ?? 'None'}');
      
      if (user != null) {
        try {
          final databaseService = Get.find<DatabaseService>();
          print('🔍 Checking user profile in database...');
          final profile = await databaseService.getUserProfile();
          print('🔍 Profile response: $profile');
          
          if (profile != null && 
              profile['display_name'] != null && 
              (profile['display_name'] as String).isNotEmpty) {
            // User has completed setup, go to home
            print('✅ User profile found, navigating to home');
            Get.offAllNamed('/home');
          } else {
            // User needs to complete setup
            print('⚠️ User profile incomplete, navigating to setup');
            Get.offAllNamed('/setup');
          }
        } catch (e) {
          print('⚠️ Error checking user profile: $e');
          // If there's an error, assume setup is needed
          Get.offAllNamed('/setup');
        }
      } else {
        // No user, go to setup
        print('⚠️ No authenticated user, navigating to setup');
        Get.offAllNamed('/setup');
      }
    } catch (e) {
      print('⚠️ Error in _checkUserSetupAndNavigate: $e');
      // If there's an error, assume setup is needed
      Get.offAllNamed('/setup');
    }
  }


  
  // Auth methods
  Future<void> signInWithEmail(String email, String password) async {
    try {
      _isLoading.value = true;
      await _authService.signInWithEmail(email, password);
      
      print('📧 Email sign-in completed, checking session...');
      _logSessionStatus();
      
      // CRITICAL FIX: Clear all cached data and refresh user data after sign in
      await _refreshAllUserDataAfterSignIn();
      
      // Clear first launch flag when user signs in successfully
      await _clearFirstLaunchFlag();
      
      await _checkUserSetupAndNavigate();
    } catch (e) {
      _handleAuthError(e, email);
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      _isLoading.value = true;
      
      // Check if user already exists and what type of account
      final accountInfo = await _authService.checkUserAccountType(email);
      
      if (accountInfo['exists'] == true) {
        if (accountInfo['type'] == 'oauth') {
          // User exists with OAuth account (Google, etc.)
      Get.snackbar(
        'Account Already Exists - OAuth Sign-in Required',
        'This email is already registered with Google. Please use "Sign in with Google" instead.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
          return;
        } else {
          // User exists with password account
          Get.snackbar(
            'Account Already Exists',
            'An account with this email already exists. Please sign in instead.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          
          // Redirect to sign in page
          Future.delayed(const Duration(seconds: 2), () {
            Get.offAllNamed('/signin', arguments: {'email': email});
          });
          return;
        }
      }
      
      // Proceed with signup since user doesn't exist
      await _authService.signUpWithEmail(email, password);
      
      Get.snackbar(
        'Success',
        'Account created! Please check your email for verification code.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      Get.offAllNamed('/otp-verification', arguments: {'email': email});
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sign up failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> signInWithGoogle() async {
    try {
      _isLoading.value = true;
      final response = await _authService.signInWithGoogle();
      
      print('🔑 Google sign-in completed, checking session...');
      _logSessionStatus();
      
      // CRITICAL FIX: Clear all cached data and refresh user data after sign in
      await _refreshAllUserDataAfterSignIn();
      
      // Clear first launch flag when user signs in successfully
      await _clearFirstLaunchFlag();
      
      // Check if user is new
      if (response.user?.createdAt != null &&
          DateTime.now().difference(DateTime.parse(response.user!.createdAt)).inMinutes < 2) {
        Get.snackbar(
          'Welcome',
          'Your Google account has been created.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      
      await _checkUserSetupAndNavigate();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Google sign in failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _isLoading.value = true;
      await _authService.sendPasswordResetEmail(email);
      
      Get.snackbar(
        'Success',
        'Password reset email sent! Check your inbox.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      Get.toNamed('/reset-password-verify', arguments: {'email': email});
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send reset email: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      _isLoading.value = true;
      await _authService.sendPasswordResetEmail(email);
      
      Get.snackbar(
        'Success',
        'OTP sent! Check your email.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      Get.offAllNamed('/reset-password-verify', arguments: {'email': email});
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send OTP: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> verifyOtpAndChangePassword(String email, String otp, String newPassword) async {
    try {
      _isLoading.value = true;
      await _authService.verifyOtpAndChangePassword(email, otp, newPassword);
      
      Get.snackbar(
        'Success',
        'Password changed! You can now sign in.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      Get.offAllNamed('/signin');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  /// Add a password to the current OAuth account
  Future<void> addPasswordToCurrentAccount(String password) async {
    try {
      _isLoading.value = true;
      
      // Check if user can add a password
      final canAddPassword = await _authService.canAddPasswordToCurrentAccount();
      if (!canAddPassword) {
        Get.snackbar(
          'Cannot Add Password',
          'You already have a password set for this account, or you are not signed in with OAuth.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
      
      // Add password to current account
      await _authService.addPasswordToCurrentAccount(password);
      
      Get.snackbar(
        'Success',
        'Password added successfully! You can now sign in with email and password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add password: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// Check if current user can add a password
  Future<bool> canAddPasswordToCurrentAccount() async {
    try {
      return await _authService.canAddPasswordToCurrentAccount();
    } catch (e) {
      print('❌ Error checking if password can be added: $e');
      return false;
    }
  }


  Future<void> verifyEmailOtp(String email, String otp) async {
    try {
      _isLoading.value = true;
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: otp,
        email: email,
      );
      
      Get.snackbar(
        'Success',
        'Email verified successfully! You can now sign in.',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      Get.offAllNamed('/signin');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Verification failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  Future<void> signOut() async {
    try {
      print('🔄 Signing out and clearing all cached data...');
      
      // CRITICAL FIX: Clear all cached data before signing out
      await _clearAllCachedData();
      
      await _authService.signOut();
      Get.offAllNamed('/signin');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sign out failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  /// Clear all cached data when signing out or switching accounts
  Future<void> _clearAllCachedData() async {
    try {
      // 1. Clear all cached territories and data
      if (Get.isRegistered<TerritoryService>()) {
        final territoryService = Get.find<TerritoryService>();
        territoryService.nearbyTerritories.clear();
        territoryService.userTerritories.clear();
        print('✅ Cleared territory service cache on sign out');
      }
      
      // 2. Clear territory history service cache
      if (Get.isRegistered<TerritoryHistoryService>()) {
        final historyService = Get.find<TerritoryHistoryService>();
        historyService.recentTerritories.clear();
        historyService.allTerritories.clear();
        print('✅ Cleared territory history cache on sign out');
      }
      
      // 3. Clear bottom sheet statistics cache
      if (Get.isRegistered<BottomSheetController>()) {
        final bottomSheetController = Get.find<BottomSheetController>();
        bottomSheetController.totalRuns.value = 0;
        print('✅ Cleared bottom sheet statistics cache on sign out');
      }
      
      // 4. Clear user preferences cache
      if (Get.isRegistered<UserPreferencesService>()) {
        final prefsService = Get.find<UserPreferencesService>();
        prefsService.username.value = '';
        prefsService.userColor.value = const Color(0xFF2196F3); // Reset to default
        print('✅ Cleared user preferences cache on sign out');
      }
      
      // 5. Clear run storage service cache
      if (Get.isRegistered<RunStorageService>()) {
        final runStorageService = Get.find<RunStorageService>();
        runStorageService.recentRuns.clear();
        print('✅ Cleared run storage service cache on sign out');
      }
      
      // 6. Clear notification service local storage to prevent mixing between accounts
      if (Get.isRegistered<UserNotificationsService>()) {
        final notificationService = Get.find<UserNotificationsService>();
        notificationService.clearLocalStorage();
        print('✅ Cleared notification service local storage on sign out');
      }
      
      // 7. Clear all SharedPreferences data EXCEPT first-launch flag
      try {
        final prefs = await SharedPreferences.getInstance();
        final bool wasFirstLaunch = prefs.getBool('isFirstLaunch') ?? false;
        await prefs.clear(); // Clears all stored preferences
        await prefs.setBool('isFirstLaunch', wasFirstLaunch);
        print('✅ SharedPreferences cleared (preserved isFirstLaunch=$wasFirstLaunch) on sign out');
      } catch (e) {
        print('⚠️ Error clearing SharedPreferences: $e');
      }

      // 8. Remove DailyChallengeService so next user gets a fresh instance
      if (Get.isRegistered<DailyChallengeService>()) {
        Get.delete<DailyChallengeService>(force: true);
        print('✅ Deleted DailyChallengeService on sign out to prevent stale daily challenge state');
      }
      
      print('✅ All cached data cleared on sign out');
      
    } catch (e) {
      print('⚠️ Error clearing cached data on sign out: $e');
      // Don't throw - this is not critical for sign out to succeed
    }
  }
  
  void _handleAuthError(dynamic error, String email) async {
    final errorMessage = error.toString();
    
    // Check if this is an "Invalid login credentials" error
    if (errorMessage.contains('Invalid login credentials') ||
        errorMessage.contains('Invalid email or password')) {
      
      // Check if the account exists and what type it is
      try {
        final accountInfo = await _authService.checkUserAccountType(email);
        
        if (accountInfo['exists'] == true) {
          if (accountInfo['type'] == 'oauth') {
            // User exists with OAuth account (Google, etc.)
            Get.snackbar(
              'Account Found - OAuth Sign-in Required',
              'This email is registered with Google. Use "Sign in with Google" or add a password in your profile.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.blue,
              colorText: Colors.white,
              duration: const Duration(seconds: 6),
            );
          } else {
            // User exists with password account but wrong password
            Get.snackbar(
              'Wrong Password',
              'The password you entered is incorrect. Please try again or use "Forgot Password".',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        } else {
          // Account doesn't exist
          Get.snackbar(
            'Account Not Found',
            'No account found with this email. Please sign up to create an account.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          
          Future.delayed(const Duration(seconds: 2), () {
            Get.offAllNamed('/signup', arguments: {'email': email});
          });
        }
      } catch (e) {
        // If we can't determine account type, show generic error
        Get.snackbar(
          'Sign In Error',
          'Unable to verify account type. Please try again or contact support.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else if (errorMessage.contains('ACCOUNT_NOT_FOUND') || 
               errorMessage.contains('User not found')) {
      Get.snackbar(
        'Account Not Found',
        'No account found with this email. Please sign up to create an account.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAllNamed('/signup', arguments: {'email': email});
      });
    } else {
      Get.snackbar(
        'Error',
        'Sign in failed: $errorMessage',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Debug method to check current session status
  void _logSessionStatus() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      
      print('🔍 Current Session Status:');
      print('  - User ID: ${user?.id ?? "null"}');
      print('  - User Email: ${user?.email ?? "null"}');
      print('  - Session Token: ${session?.accessToken != null ? "valid" : "null"}');
      print('  - Session Expires: ${session?.expiresAt != null ? DateTime.fromMillisecondsSinceEpoch(session!.expiresAt!).toString() : "null"}');
      print('  - Is Authenticated: ${user != null && session != null}');
      
      // Also check local preferences
      try {
        final prefs = Get.find<UserPreferencesService>();
        print('  - Local Username: ${prefs.username.value}');
        print('  - Has Completed Setup: ${prefs.hasCompletedSetup}');
      } catch (e) {
        print('  - Local Preferences: Not available ($e)');
      }
    } catch (e) {
      print('❌ Error checking session status: $e');
    }
  }

  /// CRITICAL FIX: Clear previous user's cached data and refresh current user data after sign in
  /// This prevents the issue where previous user's data remains visible
  Future<void> _refreshAllUserDataAfterSignIn() async {
    try {
      print('🔄 Clearing previous user data and refreshing current user data after sign in...');
      
      // 1. Clear all cached territories and data (previous user's data)
      if (Get.isRegistered<TerritoryService>()) {
        final territoryService = Get.find<TerritoryService>();
        territoryService.nearbyTerritories.clear();
        territoryService.userTerritories.clear();
        print('✅ Cleared territory service cache (previous user data)');
      }
      
      // 2. Clear territory history service cache (previous user's data)
      if (Get.isRegistered<TerritoryHistoryService>()) {
        final historyService = Get.find<TerritoryHistoryService>();
        historyService.recentTerritories.clear();
        historyService.allTerritories.clear();
        print('✅ Cleared territory history cache (previous user data)');
      }
      
      // 3. Clear bottom sheet statistics cache (previous user's data)
      if (Get.isRegistered<BottomSheetController>()) {
        final bottomSheetController = Get.find<BottomSheetController>();
        bottomSheetController.totalRuns.value = 0;
        print('✅ Cleared bottom sheet statistics cache (previous user data)');
      }
      
      // 4. Clear run storage service cache (previous user's data)
      if (Get.isRegistered<RunStorageService>()) {
        final runStorageService = Get.find<RunStorageService>();
        runStorageService.recentRuns.clear();
        print('✅ Cleared run storage service cache (previous user data)');
      }
      
      // 5. Clear notification service local storage (previous user's data)
      if (Get.isRegistered<UserNotificationsService>()) {
        final notificationService = Get.find<UserNotificationsService>();
        notificationService.clearLocalStorage();
        print('✅ Cleared notification service local storage (previous user data)');
      }
      
      // 6. DON'T clear SharedPreferences - this can interfere with session persistence
      // Instead, just refresh the current user's profile data
      print('ℹ️ Preserving SharedPreferences to maintain session state');
      
      // 7. Refresh user preferences from Supabase for current user
      if (Get.isRegistered<UserPreferencesService>()) {
        final prefsService = Get.find<UserPreferencesService>();
        await prefsService.refreshProfileFromSupabase();
        print('✅ Refreshed current user preferences from Supabase');
      }
      
      // 8. Force refresh all services to load current user's data
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure auth is complete
      
      // 9. Load fresh data for current user
      if (Get.isRegistered<TerritoryService>()) {
        final territoryService = Get.find<TerritoryService>();
        await territoryService.refreshNearbyTerritories();
        await territoryService.fetchUserTerritories();
        print('✅ Loaded fresh territory data for current user');
      }
      
      if (Get.isRegistered<TerritoryHistoryService>()) {
        final historyService = Get.find<TerritoryHistoryService>();
        await historyService.loadTerritories();
        print('✅ Loaded fresh territory history for current user');
      }
      
      print('✅ All previous user data cleared and current user data refreshed successfully');
      
    } catch (e) {
      print('⚠️ Error refreshing user data after sign in: $e');
      // Don't throw - this is not critical for sign in to succeed
    }
  }

  /// Clear the first launch flag when the user signs in successfully
  Future<void> _clearFirstLaunchFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLaunch', false);
      print('✅ First launch flag cleared successfully.');
    } catch (e) {
      print('⚠️ Error clearing first launch flag: $e');
    }
  }
}
