import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// File formats accepted for document uploads across the app.
const kAllowedDocExtensions = ['pdf', 'png', 'heic', 'jpg', 'jpeg'];

/// A document row: shows the doc name with a take-photo and an upload icon side
/// by side, or the picked file name with a remove button once attached.
class DocUploadTile extends StatelessWidget {
  const DocUploadTile({
    super.key,
    required this.label,
    required this.fileName,
    required this.onTakePhoto,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final String? fileName;
  final VoidCallback onTakePhoto;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final attached = fileName != null && fileName!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: attached ? c.primary : c.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            attached ? Icons.check_circle : Icons.description_outlined,
            size: 20,
            color: attached ? c.success : c.textSub,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.body.copyWith(color: c.textMain)),
                if (attached)
                  Text(
                    fileName!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textSub),
                  ),
              ],
            ),
          ),
          if (attached)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: c.danger),
              onPressed: onRemove,
              tooltip: 'Remove',
            )
          else ...[
            // Take photo + Upload, side by side.
            _ActionIcon(
              icon: Icons.photo_camera_outlined,
              tooltip: 'Take photo',
              onTap: onTakePhoto,
            ),
            const SizedBox(width: AppSpacing.xs),
            _ActionIcon(
              icon: Icons.upload_outlined,
              tooltip: 'Upload file',
              onTap: onUpload,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact, bordered icon button used for the take-photo / upload actions.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: c.primary.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 20, color: c.primary),
        ),
      ),
    );
  }
}
