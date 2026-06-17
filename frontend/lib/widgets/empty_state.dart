import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import 'primary_button.dart';

/// Centred empty state — icon + title + subtitle + optional CTA. Defaults to an
/// auto-rickshaw glyph (three-wheeler imagery only, per the design rules).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.electric_rickshaw,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: c.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: c.textMain),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: c.textSub),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: ctaLabel!,
                icon: Icons.add,
                onPressed: onCta,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
