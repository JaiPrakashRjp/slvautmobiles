import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../utils/app_spacing.dart';
import 'confirmation_dialog.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Approve / Reject controls shown to the Super Admin for a pending entity.
/// Renders nothing when the entity is active/rejected or the viewer is an Admin
/// (the [RoleGateBanner] already communicates pending state to admins).
class RoleGateActions extends StatelessWidget {
  const RoleGateActions({
    super.key,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  final EntityStatus status;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  Future<void> _reject(BuildContext context) async {
    final reason = await ConfirmationDialog.show(
      context,
      title: 'Reject',
      message: 'Tell the staff member why this is being rejected.',
      confirmLabel: 'Reject',
      danger: true,
      requireReason: true,
      reasonHint: 'e.g. Price below cost',
    );
    if (reason is String && reason.isNotEmpty) onReject(reason);
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.watch<AuthController>().isSuperAdmin;
    if (!isSuperAdmin || status != EntityStatus.pendingConfirmation) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: 'Reject',
            danger: true,
            onPressed: () => _reject(context),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: PrimaryButton(label: 'Approve', onPressed: onApprove),
        ),
      ],
    );
  }
}
