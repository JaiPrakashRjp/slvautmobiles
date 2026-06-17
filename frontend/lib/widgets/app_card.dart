import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';

/// Cream surface card with a 12dp radius and a soft shadow. Tappable when
/// [onTap] is provided.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.border = false,
    this.selected = false,
    this.accentLeft = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool border;

  /// Draws a thicker navy border (used for the selected module card etc.).
  final bool selected;

  /// Draws a thick navy stripe down the left edge (mockups 14–18).
  final bool accentLeft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: selected
                  ? Border.all(color: c.primary, width: 2)
                  : accentLeft
                      ? Border(left: BorderSide(color: c.primary, width: 4))
                      : border
                          ? Border.all(color: c.borderColor)
                          : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
