import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// A document row for a DETAIL/EDIT screen: manages one already-uploaded (or
/// not-yet-uploaded) document. When [attached] it shows the file name with
/// download + delete; the take-photo / upload icons are always available so the
/// user can add a new file or replace the existing one.
class DocManagerTile extends StatelessWidget {
  const DocManagerTile({
    super.key,
    required this.label,
    required this.fileName,
    required this.onTakePhoto,
    required this.onUpload,
    this.onDownload,
    this.onShare,
    this.onDelete,
    this.busy = false,
  });

  final String label;
  final String? fileName; // null/empty = nothing uploaded yet
  final VoidCallback onTakePhoto;
  final VoidCallback onUpload;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool busy;

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
          if (busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (attached && onDownload != null)
              _ActionIcon(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onTap: onDownload!,
              ),
            if (attached && onShare != null)
              _ActionIcon(
                icon: Icons.share_outlined,
                tooltip: 'Share',
                onTap: onShare!,
              ),
            _ActionIcon(
              icon: Icons.upload_outlined,
              tooltip: attached ? 'Replace (upload)' : 'Upload file',
              onTap: onUpload,
            ),
            if (!attached)
              _ActionIcon(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Take photo',
                onTap: onTakePhoto,
              ),
            if (attached && onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: c.danger),
                onPressed: onDelete,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Tooltip(
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
      ),
    );
  }
}
