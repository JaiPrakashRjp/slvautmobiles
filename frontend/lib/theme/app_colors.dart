import 'package:flutter/material.dart';

/// SLV brand palette delivered as a [ThemeExtension] so every widget reads
/// colours through `context.colors.*` and never hard-codes a hex value.
///
/// The light palette is LOCKED — values come straight from the SLV logo and
/// are confirmed by the owner. The dark palette mirrors the same shape
/// (canvas/surface inverted, navy lifted slightly, gold preserved).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgContainer,
    required this.primary,
    required this.primaryHover,
    required this.primaryContainer,
    required this.onPrimary,
    required this.accent,
    required this.textMain,
    required this.textSub,
    required this.borderColor,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
  });

  final Color bgCanvas;
  final Color bgSurface;
  final Color bgContainer;
  final Color primary;
  final Color primaryHover;
  final Color primaryContainer;
  final Color onPrimary;
  final Color accent;
  final Color textMain;
  final Color textSub;
  final Color borderColor;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;

  /// Light mode (default).
  static const AppColors light = AppColors(
    bgCanvas: Color(0xFFE0DDD3), // warm grey app background
    bgSurface: Color(0xFFF5F3EE), // cream card surface
    bgContainer: Color(0xFFFFFFFF), // input fields, dialogs
    primary: Color(0xFF1B2A4E), // SLV navy — buttons, headers
    primaryHover: Color(0xFF142038),
    primaryContainer: Color(0xFFE3E6EE), // navy tint for backgrounds
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFD4A848), // SLV gold — FAB, active tab indicator
    textMain: Color(0xFF0F1A33),
    textSub: Color(0xFF6B7280),
    borderColor: Color(0xFFD7D3C7),
    success: Color(0xFF1F7A4D),
    successTint: Color(0xFFE7F1EA),
    warning: Color(0xFFC8852A),
    warningTint: Color(0xFFF7EDD9),
    danger: Color(0xFF9E2A2A),
    dangerTint: Color(0xFFF4DDDD),
  );

  /// Dark mode (same shape; canvas/surface inverted, navy lifted, gold kept).
  static const AppColors dark = AppColors(
    bgCanvas: Color(0xFF12161F), // deep slate canvas
    bgSurface: Color(0xFF1B2230), // raised card surface
    bgContainer: Color(0xFF232C3D), // inputs, dialogs
    primary: Color(0xFF2E436F), // lifted navy for contrast on dark
    primaryHover: Color(0xFF3A5285),
    primaryContainer: Color(0xFF22304E),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFD4A848), // gold preserved
    textMain: Color(0xFFF1F2F5),
    textSub: Color(0xFF9AA3B2),
    borderColor: Color(0xFF2C3647),
    success: Color(0xFF4FB07E),
    successTint: Color(0xFF1B3328),
    warning: Color(0xFFE0A24A),
    warningTint: Color(0xFF3A2F1B),
    danger: Color(0xFFD06262),
    dangerTint: Color(0xFF3A2424),
  );

  @override
  AppColors copyWith({
    Color? bgCanvas,
    Color? bgSurface,
    Color? bgContainer,
    Color? primary,
    Color? primaryHover,
    Color? primaryContainer,
    Color? onPrimary,
    Color? accent,
    Color? textMain,
    Color? textSub,
    Color? borderColor,
    Color? success,
    Color? successTint,
    Color? warning,
    Color? warningTint,
    Color? danger,
    Color? dangerTint,
  }) {
    return AppColors(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSurface: bgSurface ?? this.bgSurface,
      bgContainer: bgContainer ?? this.bgContainer,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      textMain: textMain ?? this.textMain,
      textSub: textSub ?? this.textSub,
      borderColor: borderColor ?? this.borderColor,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      danger: danger ?? this.danger,
      dangerTint: dangerTint ?? this.dangerTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgContainer: Color.lerp(bgContainer, other.bgContainer, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      success: Color.lerp(success, other.success, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
    );
  }
}

/// `context.colors.*` accessor used everywhere in the app.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
