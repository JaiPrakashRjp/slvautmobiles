import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_text_styles.dart';

class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Navy bottom navigation bar with a gold accent on the active item.
/// On tablet, callers use a [NavigationRail] instead (see ResponsiveScaffold).
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<BottomNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 22,
                          color: i == index ? c.accent : c.onPrimary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: AppTextStyles.caption.copyWith(
                            color: i == index ? c.accent : c.onPrimary,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
