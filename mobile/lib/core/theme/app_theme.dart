import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kiểu chữ dùng riêng cho số tiền (chữ số rộng bằng nhau để các cột thẳng hàng).
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  static const moneyHero = TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1, fontFeatures: _tabular);
  static const moneyLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: _tabular);
  static const moneyMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: _tabular);
  static const moneySmall = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: _tabular);

  static const sectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'BeVietnamPro';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryDark,
      error: AppColors.expense,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);

    return base.copyWith(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(activeTrackColor: AppColors.primary, thumbColor: AppColors.primary),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),
    );
  }
}
