import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_text_styles.dart';

/// Segmented tab bar: navy fill on the active segment, cream on the rest
/// (matches mockups 04 and 11). Controlled — parent owns [index].
class TabBarNavy extends StatelessWidget {
  const TabBarNavy({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.borderColor),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? c.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTextStyles.label.copyWith(
                      color: i == index ? c.onPrimary : c.textSub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
