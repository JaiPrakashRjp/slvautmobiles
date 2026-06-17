import 'package:flutter/material.dart';

/// Named text styles. Sizes/weights are LOCKED by the design system; colour is
/// left null so the active [TextTheme]/`context.colors.textMain` supplies it.
/// Pair with `.copyWith(color: context.colors.*)` at the call site when a
/// specific colour is needed.
class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle pageTitle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25);
  static const TextStyle h2 =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3);
  static const TextStyle body =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle bodyStrong =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4);
  static const TextStyle label =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle caption =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3);
}
