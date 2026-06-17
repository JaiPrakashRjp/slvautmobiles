import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';

/// Gold "+ Create" pill shown in module app bars (mockup 04). When [iconOnly]
/// is true it renders the compact "+" square (mockup 07).
class GoldCreateButton extends StatelessWidget {
  const GoldCreateButton({
    super.key,
    required this.onPressed,
    this.label = 'Create',
    this.iconOnly = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: c.accent,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 10 : 14,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18, color: c.textMain),
                if (!iconOnly) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
