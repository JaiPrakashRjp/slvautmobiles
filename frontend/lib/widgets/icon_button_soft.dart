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
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = danger ? c.danger : c.primary;
    final btn = Material(
      color: danger ? c.dangerTint : c.bgCanvas,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: SizedBox(
          height: 40,
          width: 40,
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
