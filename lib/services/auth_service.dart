
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/env_config.dart';

class AuthService {
  // Forgot password (send reset email)
  Future<void> sendPasswordResetEmail(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  // Verify OTP and change password
  Future<void> verifyOtpAndChangePassword(String email, String otp, String newPassword) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.auth.verifyOTP(
      type: OtpType.recovery,
      token: otp,
      email: email,
    );
    if (response.session != null) {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } else {
      throw Exception('Invalid or expired OTP');
    }
  }

  // Email/password sign in
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Email/password sign up
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Google sign in with proper server client ID for session persistence
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: EnvConfig.googleServerClientId,
    );
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');
    final auth = await account.authentication;
    if (auth.idToken == null) {
      throw Exception('Google sign-in failed: missing idToken. Ensure GOOGLE_SERVER_CLIENT_ID is configured.');
    }
    
    // Sign in with Supabase using the ID token
    final response = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
      accessToken: auth.accessToken,
    );
    
    // Ensure session is properly set
    if (response.session == null) {
      throw Exception('Google sign-in failed: no session created');
    }
    
    print('✅ Google sign-in successful, session created for user: ${response.user?.id}');
    return response;
  }

  // Sign out
  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    await GoogleSignIn().signOut();
  }

  /// Check if a user email already exists in the system
  /// Returns a map with existence status and account type
  /// 
  /// Example usage:
  /// ```dart
  /// final authService = AuthService();
  /// final result = await authService.checkUserAccountType('user@example.com');
  /// if (result['exists'] == true) {
  ///   if (result['type'] == 'oauth') {
  ///     print('User exists with OAuth account');
  ///   } else if (result['type'] == 'password') {
  ///     print('User exists with password account');
  ///   }
  /// } else {
  ///   print('User does not exist');
  /// }
  /// ```
  Future<Map<String, dynamic>> checkUserAccountType(String email) async {
    try {
      // Try to sign in with the email and a dummy password
      // This will help us determine if the account exists and what type it is
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: 'dummy_password_for_existence_check',
      );
      // If we reach here, the email exists and password was correct (unlikely with dummy password)
      // Sign out immediately to avoid any session issues
      await Supabase.instance.client.auth.signOut();
      return {'exists': true, 'type': 'password'};
    } on AuthException catch (e) {
      // Check the error message to determine account type
      if (e.message.contains('Invalid login credentials') || 
          e.message.contains('Invalid email or password')) {
        // User exists but password is wrong - could be OAuth or password account
        // Try to get more info about the account
        try {
          // Check if we can get user info without password (OAuth account)
          final response = await Supabase.instance.client.auth.admin.listUsers();
          final user = response.firstWhere(
            (u) => u.email == email,
            orElse: () => throw Exception('User not found in admin list'),
          );
          
          // Check if user has any OAuth providers
          final hasOAuthProviders = user.appMetadata['providers'] != null && 
                                   (user.appMetadata['providers'] as List).isNotEmpty;
          
          if (hasOAuthProviders) {
            return {'exists': true, 'type': 'oauth'};
          } else {
            return {'exists': true, 'type': 'password'};
          }
        } catch (adminError) {
          // If we can't check admin info, assume it's a password account
          return {'exists': true, 'type': 'password'};
        }
      } else if (e.message.contains('Email not confirmed')) {
        // User exists but email not confirmed - likely password account
        return {'exists': true, 'type': 'password'};
      } else if (e.message.contains('User not found') ||
                 e.message.contains('Email not found')) {
        // User doesn't exist
        return {'exists': false, 'type': null};
      } else {
        // For other errors, assume user doesn't exist to be safe
        print('⚠️ Auth error during user existence check: ${e.message}');
        return {'exists': false, 'type': null};
      }
    } catch (e) {
      // For any other unexpected errors, assume user doesn't exist
      print('⚠️ Unexpected error during user existence check: $e');
      return {'exists': false, 'type': null};
    }
  }

  /// Check if a user email already exists in the system (legacy method for backward compatibility)
  Future<bool> doesUserExist(String email) async {
    final result = await checkUserAccountType(email);
    return result['exists'] == true;
  }

  /// Add a password to the current user's account (must be signed in)
  /// This allows OAuth users to also sign in with email/password
  Future<void> addPasswordToCurrentAccount(String password) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in. Please sign in first.');
      }

      // Update the user's password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      
      print('✅ Password successfully added to current account');
    } catch (e) {
      print('❌ Error adding password to account: $e');
      throw Exception('Failed to add password: $e');
    }
  }

  /// Check if the current user can add a password (i.e., they're signed in via OAuth)
  Future<bool> canAddPasswordToCurrentAccount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Check if user has OAuth providers (Google, etc.)
      final providers = user.appMetadata['providers'] as List<dynamic>?;
      final hasOAuthProviders = providers != null && providers.isNotEmpty;
      
      // Check if user already has a password by trying to sign in
      // If they can sign in with a dummy password, they already have a password
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: user.email!,
          password: 'dummy_check_password',
        );
        // If we get here, they already have a password
        await Supabase.instance.client.auth.signOut();
        return false; // Already has password
      } catch (e) {
        // If sign in fails, they don't have a password yet
        return hasOAuthProviders; // Can add password if they have OAuth
      }
    } catch (e) {
      print('❌ Error checking if password can be added: $e');
      return false;
    }
  }

  /// Link a password to an existing OAuth account (legacy method)
  Future<AuthResponse> linkPasswordToOAuthAccount(String email, String password) async {
    try {
      // This method is deprecated - use addPasswordToCurrentAccount instead
      throw Exception('This method is deprecated. Please use addPasswordToCurrentAccount() after signing in with OAuth.');
    } catch (e) {
      throw Exception('Unable to link password: $e');
    }
  }
}
