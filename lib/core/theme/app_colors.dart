import 'package:flutter/material.dart';

/// Central color tokens for Trackt's flat, modern, minimal design system.
/// One restrained accent, neutral dark surfaces, no gradients/glows.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFF0F0F11);
  static const Color surface = Color(0xFF17171A);
  static const Color surfaceVariant = Color(0xFF202024);
  static const Color border = Color(0xFF2A2A2F);

  // Text
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Accent — a single calm indigo (works with white text, used flat)
  static const Color accent = Color(0xFF6366F1);
  static const Color accentPressed = Color(0xFF4F46E5);
  static const Color onAccent = Color(0xFFFFFFFF);

  // Semantic
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
