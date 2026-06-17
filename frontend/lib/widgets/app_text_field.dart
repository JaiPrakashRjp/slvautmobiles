import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// Labelled text field on a cream fill with a navy focus border. Wraps
/// [TextFormField] so it works inside a [Form] with validators.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixText,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.onChanged,
    this.enabled = true,
    this.initialValue,
    this.textInputAction,
    this.required = false,
  });

  final String? label;
  final bool required;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? initialValue;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: c.borderColor),
    );

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
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          enabled: enabled,
          textInputAction: textInputAction,
          style: AppTextStyles.body.copyWith(color: c.textMain),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: AppTextStyles.body.copyWith(color: c.textMain),
            hintStyle: AppTextStyles.body.copyWith(color: c.textSub),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? c.bgContainer : c.bgSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: c.danger, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
