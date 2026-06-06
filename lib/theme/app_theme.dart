import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.teaAmber,
      primary: AppColors.teaAmberDeep,
      secondary: AppColors.sakuraPink,
      tertiary: AppColors.deepPurple,
      surface: AppColors.parchment,
      surfaceTint: AppColors.sakuraMist,
      error: const Color(0xFFB3261E),
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      useMaterial3: true,
      fontFamilyFallback: const [
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'sans-serif',
      ],
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.parchment,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0x55FFFFFF)),
        ),
        shadowColor: AppShadows.soft.first.color,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.parchment,
        selectedColor: AppColors.lavender,
        secondarySelectedColor: AppColors.sakuraMist,
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.deepPurple,
          fontWeight: FontWeight.w800,
        ),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.parchment.withValues(alpha: 0.94),
        indicatorColor: AppColors.sakuraMist,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.deepPurple : AppColors.mutedInk,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.teaAmberDeep : AppColors.mutedInk,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teaAmberDeep,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.teaAmberDeep,
        inactiveTrackColor: AppColors.sakuraMist,
        thumbColor: AppColors.deepPurple,
        overlayColor: AppColors.sakuraPink.withValues(alpha: 0.18),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
      ),
    );
  }
}
