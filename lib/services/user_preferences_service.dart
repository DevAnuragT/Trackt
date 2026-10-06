import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class UserPreferencesService extends GetxService {
  static const String _usernameKey = 'username';
  static const String _userColorKey = 'userColor';
  static const String _isFirstLaunchKey = 'isFirstLaunch';
  static const String _userCoinsKey = 'userCoins';

  late SharedPreferences _prefs;
  late DatabaseService _databaseService;

  final RxString username = ''.obs;
  final Rx<Color> userColor = const Color(0xFF2196F3).obs; // Blue color as default
  final RxBool isFirstLaunch = true.obs;
  final RxInt userCoins = 0.obs;

  Future<UserPreferencesService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _databaseService = DatabaseService(); // Initialize database service
    await _loadPreferences();
    return this;
  }

  Future<void> _loadPreferences() async {
    username.value = _prefs.getString(_usernameKey) ?? '';
    final colorValue = _prefs.getInt(_userColorKey);
    if (colorValue != null) {
      userColor.value = Color(colorValue);
    }
    
    // Load first launch flag with better debugging
    final firstLaunchValue = _prefs.getBool(_isFirstLaunchKey);
    print('🔍 Loading first launch flag: $firstLaunchValue (key: $_isFirstLaunchKey)');
    isFirstLaunch.value = firstLaunchValue ?? true;
    
    userCoins.value = _prefs.getInt(_userCoinsKey) ?? 0;
    
    // Try to load user color from Supabase if authenticated
    await _loadColorFromSupabase();
  }

  /// Load user profile from Supabase (color and username)
  Future<void> _loadColorFromSupabase() async {
    try {
      if (_databaseService.isAuthenticated) {
        print('🔍 Loading user profile from Supabase...');
        final profile = await _databaseService.getUserProfile();
        print('🔍 Profile response: $profile');
        
        if (profile != null) {
          // Load color
          if (profile['user_color'] != null) {
            String colorHex = profile['user_color'];
            if (colorHex.isNotEmpty) {
              // Parse color from hex string
              Color supabaseColor = _parseColorFromHex(colorHex);
              userColor.value = supabaseColor;
              // Update local storage to match Supabase
              await _prefs.setInt(_userColorKey, supabaseColor.value);
              print('✅ Loaded user color from Supabase: $colorHex');
            }
          }
          
          // Load username/display name
          if (profile['display_name'] != null && profile['display_name'].isNotEmpty) {
            String displayName = profile['display_name'];
            username.value = displayName;
            // Update local storage to match Supabase
            await _prefs.setString(_usernameKey, displayName);
            print('✅ Loaded username from Supabase: $displayName');
          }
          
          // Load user coins
          if (profile['coins'] != null) {
            int coins = profile['coins'] ?? 0;
            userCoins.value = coins;
            // Update local storage to match Supabase
            await _prefs.setInt(_userCoinsKey, coins);
            print('✅ Loaded user coins from Supabase: $coins');
          }
        } else {
          print('⚠️ No profile found in Supabase');
        }
      } else {
        print('⚠️ User not authenticated, skipping Supabase profile load');
      }
    } catch (e) {
      print('⚠️ Failed to load profile from Supabase: $e');
      // Continue with local values
    }
  }

  /// Refresh user profile from Supabase (public method for external calls)
  Future<void> refreshProfileFromSupabase() async {
    print('🔄 Refreshing user profile from Supabase...');
    await _loadColorFromSupabase();
    print('✅ User profile refresh completed');
  }

  /// Force refresh user profile (for debugging)
  Future<void> forceRefreshProfile() async {
    print('🔄 Force refreshing user profile...');
    try {
      if (_databaseService.isAuthenticated) {
        final profile = await _databaseService.getUserProfile();
        print('🔍 Force refresh profile response: $profile');
        
        if (profile != null) {
          // Load color
          if (profile['user_color'] != null) {
            String colorHex = profile['user_color'];
            if (colorHex.isNotEmpty) {
              Color supabaseColor = _parseColorFromHex(colorHex);
              userColor.value = supabaseColor;
              await _prefs.setInt(_userColorKey, supabaseColor.value);
              print('✅ Force refresh: Loaded user color: $colorHex');
            }
          }
          
          // Load username/display name
          if (profile['display_name'] != null && profile['display_name'].isNotEmpty) {
            String displayName = profile['display_name'];
            username.value = displayName;
            await _prefs.setString(_usernameKey, displayName);
            print('✅ Force refresh: Loaded username: $displayName');
          }
          
          // Load user coins
          if (profile['coins'] != null) {
            int coins = profile['coins'] ?? 0;
            userCoins.value = coins;
            await _prefs.setInt(_userCoinsKey, coins);
            print('✅ Force refresh: Loaded user coins: $coins');
          }
        }
      }
    } catch (e) {
      print('❌ Force refresh failed: $e');
    }
  }

  /// Parse color from hex string
  Color _parseColorFromHex(String hexString) {
    try {
      if (hexString.startsWith('#')) {
        String hex = hexString.replaceAll('#', '');
        if (hex.length == 6) {
          hex = 'FF$hex'; // Add alpha if missing
        }
        return Color(int.parse(hex, radix: 16));
      }
      return const Color(0xFF2196F3); // Default blue
    } catch (e) {
      print('⚠️ Error parsing color hex: $hexString');
      return const Color(0xFF2196F3); // Default blue
    }
  }

  Future<void> setUsername(String name) async {
    await _prefs.setString(_usernameKey, name);
    username.value = name;
    
    // Sync with Supabase if user is authenticated
    try {
      if (_databaseService.isAuthenticated) {
        await _databaseService.updateUserDisplayName(name);
        print('✅ Username synced to Supabase: $name');
      }
    } catch (e) {
      print('⚠️ Failed to sync username to Supabase: $e');
      // Continue with local storage even if cloud sync fails
    }
  }

  Future<void> setUserColor(Color color) async {
    await _prefs.setInt(_userColorKey, color.value);
    userColor.value = color;
    
    // Sync with Supabase if user is authenticated
    try {
      if (_databaseService.isAuthenticated) {
        String colorHex = '#${color.value.toRadixString(16).toUpperCase()}';
        await _databaseService.updateUserColor(colorHex);
        print('✅ Color synced to Supabase: $colorHex');
      }
    } catch (e) {
      print('⚠️ Failed to sync color to Supabase: $e');
      // Continue with local storage even if cloud sync fails
    }
  }
  
  Future<void> setUserCoins(int coins) async {
    await _prefs.setInt(_userCoinsKey, coins);
    userCoins.value = coins;
    
    // Sync with Supabase if user is authenticated
    try {
      if (_databaseService.isAuthenticated) {
        await _databaseService.updateUserCoins(coins);
        print('✅ Coins synced to Supabase: $coins');
      }
    } catch (e) {
      print('⚠️ Failed to sync coins to Supabase: $e');
      // Continue with local storage even if cloud sync fails
    }
  }
  
  Future<void> addUserCoins(int coinsToAdd) async {
    final newTotal = userCoins.value + coinsToAdd;
    await setUserCoins(newTotal);
    print('✅ Added $coinsToAdd coins. New total: $newTotal');
  }

  /// Set first launch as completed with better debugging
  Future<void> setFirstLaunchCompleted() async {
    print('🔍 Setting first launch as completed...');
    await _prefs.setBool(_isFirstLaunchKey, false);
    isFirstLaunch.value = false;
    
    // Verify the value was saved
    final savedValue = _prefs.getBool(_isFirstLaunchKey);
    print('✅ First launch flag saved: $savedValue (key: $_isFirstLaunchKey)');
    
    // Also check if we have a username
    final hasUsername = username.value.isNotEmpty;
    print('🔍 Username status: ${hasUsername ? "Set" : "Not set"} (${username.value})');
  }

  /// Check if user has completed setup (local storage only, no Supabase dependency)
  bool get hasCompletedSetup {
    final localUsername = _prefs.getString(_usernameKey);
    final hasUsername = localUsername != null && localUsername.isNotEmpty;
    
    // Debug logging
    print('🔍 hasCompletedSetup check:');
    print('  - Username: "$localUsername"');
    print('  - Has username: $hasUsername');
    print('  - First launch: ${isFirstLaunch.value}');
    
    return hasUsername;
  }
  
  /// Check if this is a fresh app install (no username, not first launch)
  bool get isFreshAppInstall {
    // If this is not the first launch but we have no username,
    // it likely means this is a fresh app install
    if (!isFirstLaunch.value && username.value.isEmpty) {
      print('🆕 Fresh app install detected (not first launch but no username)');
      return true;
    }
    return false;
  }
  
  /// Reset to first launch state (useful when app data is cleared or fresh install)
  Future<void> resetToFirstLaunch() async {
    print('🔄 Resetting to first launch state...');
    await _prefs.setBool(_isFirstLaunchKey, true);
    isFirstLaunch.value = true;
    username.value = '';
    userColor.value = const Color(0xFF2196F3);
    userCoins.value = 0;
    
    // Also clear from SharedPreferences directly
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLaunch', true);
      print('✅ First launch flag set in SharedPreferences');
    } catch (e) {
      print('⚠️ Error setting first launch flag in SharedPreferences: $e');
    }
    
    print('✅ Reset to first launch state completed');
  }
  
  /// Get username from local storage only (no Supabase dependency)
  String get localUsername {
    return _prefs.getString(_usernameKey) ?? '';
  }
}
