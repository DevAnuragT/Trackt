import 'package:flutter/material.dart';
import 'package:trackt/views/main_navigation_view.dart';
import 'package:trackt/views/auth/signin_view.dart';
import 'package:trackt/views/splash_view.dart';
import '../views/auth/signup_view.dart';
import '../views/profile_view.dart';
import '../views/auth/otp_verification_view.dart';
import '../views/setup/first_launch_setup_page.dart';
import '../views/setup/app_intro_page.dart';
import '../views/profile/run_history_page.dart';
import '../views/profile/notifications_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String intro = '/intro';
  static const String setup = '/setup';
  static const String profile = '/profile';
  static const String territoryHistory = '/territory-history';
  static const String notifications = '/notifications';
  static const String otpVerification = '/otp-verification';
  static const String resetPasswordRequest = '/reset-password-request';
  // Removed add password route

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashView(),
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationView(),
        );
      case signIn:
        return MaterialPageRoute(
          builder: (_) => const SignInView(),
        );
      case signUp:
        return MaterialPageRoute(
          builder: (_) => const SignUpView(),
        );
      case intro:
        return MaterialPageRoute(
          builder: (_) => const AppIntroPage(),
        );
      case setup:
        return MaterialPageRoute(
          builder: (_) => const FirstLaunchSetupPage(),
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileView(),
        );
      case territoryHistory:
        return MaterialPageRoute(
          builder: (_) => const TerritoryHistoryPage(),
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsPage(),
        );
      case otpVerification:
        final args = settings.arguments as Map<String, dynamic>?;
        final email = args?['email'] as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => OTPVerificationView(email: email),
        );
  // Removed AddPasswordView route
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
