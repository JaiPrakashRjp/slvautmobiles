import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_text_styles.dart';

enum PillVariant { success, warning, danger, info, neutral }

/// Pill-shaped status indicator with tinted background + coloured label.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.variant});

  final String label;
  final PillVariant variant;

  /// Maps a gated-entity status to a pill.
  factory StatusPill.forEntity(EntityStatus status, {Key? key}) {
    return switch (status) {
      EntityStatus.active =>
        StatusPill(key: key, label: status.label, variant: PillVariant.success),
      EntityStatus.pendingConfirmation =>
        StatusPill(key: key, label: status.label, variant: PillVariant.warning),
      EntityStatus.rejected =>
        StatusPill(key: key, label: status.label, variant: PillVariant.danger),
    };
  }

  /// Maps a schedule status (installment/EMI/collection) to a pill.
  factory StatusPill.forSchedule(ScheduleStatus status, {Key? key}) {
    final variant = switch (status) {
      ScheduleStatus.paid => PillVariant.success,
      ScheduleStatus.upcoming => PillVariant.info,
      ScheduleStatus.dueSoon => PillVariant.warning,
      ScheduleStatus.partial => PillVariant.warning,
      ScheduleStatus.overdue => PillVariant.danger,
    };
    return StatusPill(key: key, label: status.label, variant: variant);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (variant) {
      PillVariant.success => (c.successTint, c.success),
      PillVariant.warning => (c.warningTint, c.warning),
      PillVariant.danger => (c.dangerTint, c.danger),
      PillVariant.info => (c.primaryContainer, c.primary),
      PillVariant.neutral => (c.bgCanvas, c.textSub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: fg),
      ),
    );
  }
}
