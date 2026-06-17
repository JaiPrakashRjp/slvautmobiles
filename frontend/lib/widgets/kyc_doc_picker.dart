import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// Selectable KYC document chips (mockup 08). In the mock layer tapping a chip
/// marks the document as attached; Phase 7 swaps this for an image_picker
/// capture per chip.
class KycDocPicker extends StatelessWidget {
  const KycDocPicker({
    super.key,
    this.types = const [KycDocType.aadhaar, KycDocType.dl, KycDocType.pan],
    required this.selected,
    required this.onToggle,
  });

  final List<KycDocType> types;
  final Set<KycDocType> selected;
  final ValueChanged<KycDocType> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final t in types)
          GestureDetector(
            onTap: () => onToggle(t),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: selected.contains(t) ? c.primaryContainer : c.bgContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected.contains(t) ? c.primary : c.borderColor,
                  width: selected.contains(t) ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected.contains(t)) ...[
                    Icon(Icons.check, size: 16, color: c.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    t.label,
                    style: AppTextStyles.body.copyWith(
                      color: selected.contains(t) ? c.primary : c.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
