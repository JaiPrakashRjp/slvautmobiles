import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// A field-styled box that opens a picker (date / dropdown sheet) on tap.
/// Mirrors [AppTextField]'s look so forms stay visually consistent.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    this.label,
    required this.value,
    this.placeholder = 'Select',
    this.leadingIcon,
    this.trailingIcon = Icons.expand_more,
    required this.onTap,
    this.enabled = true,
    this.required = false,
  });

  final String? label;
  final bool required;

  /// Current display value, or null to show [placeholder].
  final String? value;
  final String placeholder;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              text: label!,
              style: AppTextStyles.label.copyWith(color: c.textSub),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: AppTextStyles.label.copyWith(color: c.danger),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: enabled ? c.bgContainer : c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: c.borderColor),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: c.textSub),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    hasValue ? value! : placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: hasValue ? c.textMain : c.textSub,
                    ),
                  ),
                ),
                Icon(trailingIcon, size: 20, color: c.textSub),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
