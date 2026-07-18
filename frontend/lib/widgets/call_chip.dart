import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_text_styles.dart';
import '../utils/formatters.dart';

/// A tappable phone chip — tap opens the phone dialer with the number ready to
/// call. Shown on the customer card and on a sold vehicle's owner line.
class CallChip extends StatelessWidget {
  const CallChip({super.key, required this.phone});

  final String phone;

  Future<void> _call() async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: _call,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: c.successTint,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call, size: 14, color: c.success),
            const SizedBox(width: 5),
            Text(Formatters.phone(phone),
                style: AppTextStyles.caption
                    .copyWith(color: c.success, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
