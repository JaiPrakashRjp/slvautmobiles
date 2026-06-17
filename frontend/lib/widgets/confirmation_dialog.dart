import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import 'app_text_field.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Reusable confirm dialog for delete / approve / reject flows.
///
/// Returns `true` on confirm, `null`/`false` on cancel. When [requireReason]
/// is set, the confirm callback receives the entered reason (used for reject).
class ConfirmationDialog extends StatefulWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.danger = false,
    this.requireReason = false,
    this.reasonHint,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool requireReason;
  final String? reasonHint;

  /// Shows the dialog. With [requireReason], resolves to the entered reason
  /// string on confirm; otherwise resolves to `true`. Resolves to null on cancel.
  static Future<Object?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
    bool requireReason = false,
    String? reasonHint,
  }) {
    return showDialog<Object?>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        requireReason: requireReason,
        reasonHint: reasonHint,
      ),
    );
  }

  @override
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.requireReason && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a reason');
      return;
    }
    Navigator.of(context)
        .pop(widget.requireReason ? _reason.text.trim() : true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.bgContainer,
      title: Text(widget.title, style: AppTextStyles.h2.copyWith(color: c.textMain)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message,
              style: AppTextStyles.body.copyWith(color: c.textSub)),
          if (widget.requireReason) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _reason,
              hint: widget.reasonHint ?? 'Reason',
              maxLines: 3,
              minLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: c.danger)),
            ],
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: widget.cancelLabel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                label: widget.confirmLabel,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
