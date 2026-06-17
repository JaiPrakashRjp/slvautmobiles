import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// Yellow banner shown at the top of a pending item, or a red banner with the
/// reason when an item was rejected. Renders nothing for active items.
class RoleGateBanner extends StatelessWidget {
  const RoleGateBanner({
    super.key,
    required this.status,
    this.rejectionReason,
    this.createdByLabel,
  });

  final EntityStatus status;
  final String? rejectionReason;
  final String? createdByLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (status == EntityStatus.active) return const SizedBox.shrink();

    final isRejected = status == EntityStatus.rejected;
    final bg = isRejected ? c.dangerTint : c.warningTint;
    final fg = isRejected ? c.danger : c.warning;
    final icon = isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded;
    final title = isRejected
        ? 'Rejected by Super admin'
        : 'Pending Super admin approval';
    final subtitle = isRejected
        ? (rejectionReason ?? 'No reason provided')
        : (createdByLabel != null
            ? 'Submitted by $createdByLabel — awaiting confirmation'
            : 'This record takes effect once the Super admin confirms it');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong.copyWith(color: fg)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
