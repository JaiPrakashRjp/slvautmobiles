import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import 'app_card.dart';

/// Read-only label-over-value card used on detail screens (mockups 06, 16).
/// Pass [valueWidget] to render a pill or custom content instead of text.
class DetailFieldCard extends StatelessWidget {
  const DetailFieldCard({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
  }) : assert(value != null || valueWidget != null);

  final String label;
  final String? value;
  final Widget? valueWidget;

  /// Overrides the value text colour (e.g. red for an expired document date).
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.xs),
          valueWidget ??
              Text(value!,
                  style: AppTextStyles.h2
                      .copyWith(color: valueColor ?? c.textMain)),
        ],
      ),
    );
  }
}
