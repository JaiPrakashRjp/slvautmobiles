import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_radius.dart';
import 'app_colors.dart';

/// Builds light/dark [ThemeData] from the locked [AppColors] palette and the
/// Inter font (pulled at runtime by google_fonts — no bundled .ttf).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: c.textMain,
      displayColor: c.textMain,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      surface: c.bgSurface,
      onSurface: c.textMain,
      error: c.danger,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgCanvas,
      canvasColor: c.bgCanvas,
      textTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.onPrimary,
        ),
        iconTheme: IconThemeData(color: c.onPrimary),
      ),
      dividerColor: c.borderColor,
      iconTheme: IconThemeData(color: c.textMain),
      dialogTheme: DialogThemeData(
        backgroundColor: c.bgContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primary,
        contentTextStyle: TextStyle(color: c.onPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
