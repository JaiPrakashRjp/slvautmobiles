import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';

/// Small grey-tile square icon button used inside cards (eye / trash etc.).
class IconButtonSoft extends StatelessWidget {
  const IconButtonSoft({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.danger = false,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool danger;

  /// Smaller tile (32×32, icon 16) for the two-row card action strip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = danger ? c.danger : c.primary;
    final dim = compact ? 32.0 : 40.0;
    final iconSize = compact ? 16.0 : 18.0;
    final btn = Material(
      color: danger ? c.dangerTint : c.bgCanvas,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: SizedBox(
          height: dim,
          width: dim,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
