import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFFC96A3A);
  static const accentMid = Color(0xFFD4845A);

  // Light mode
  static const bgLight = Color(0xFFF7F4EF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF0EDE6);
  static const surfaceHoverLight = Color(0xFFEAE6DE);
  static const borderLight = Color(0xFFE8E2D8);
  static const borderLightAlt = Color(0xFFF0EDE6);
  static const textLight = Color(0xFF1C1A16);
  static const textSecLight = Color(0xFF6B6357);
  static const textMutedLight = Color(0xFFA89E90);

  // Dark mode
  static const bgDark = Color(0xFF141210);
  static const surfaceDark = Color(0xFF1E1C19);
  static const surfaceAltDark = Color(0xFF28251F);
  static const surfaceHoverDark = Color(0xFF2E2B24);
  static const borderDark = Color(0xFF2E2B24);
  static const borderDarkAlt = Color(0xFF252219);
  static const textDark = Color(0xFFEDE9E2);
  static const textSecDark = Color(0xFF8A8478);
  static const textMutedDark = Color(0xFF4A4640);

  static const green = Color(0xFF5AAE6A);
  static const red = Color(0xFFE05030);
  static const blue = Color(0xFF5BA8D4);
  static const gold = Color(0xFFC9972A);
}

class AppTheme {
  final bool isDark;

  const AppTheme({this.isDark = false});

  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get surfaceAlt => isDark ? AppColors.surfaceAltDark : AppColors.surfaceAltLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get borderLight => isDark ? AppColors.borderDarkAlt : AppColors.borderLightAlt;
  Color get text => isDark ? AppColors.textDark : AppColors.textLight;
  Color get textSec => isDark ? AppColors.textSecDark : AppColors.textSecLight;
  Color get textMuted => isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
  Color get accent => AppColors.accent;
  Color get accentMid => AppColors.accentMid;
  Color get accentSoft => isDark
      ? AppColors.accent.withValues(alpha: 0.15)
      : AppColors.accent.withValues(alpha: 0.10);

  BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8)]
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 4),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 16),
              ],
      );
}
