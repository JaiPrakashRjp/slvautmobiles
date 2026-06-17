import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Navy circular badge with the "SLV" wordmark (matches login mockup 01).
/// Used until a packaged auto-rickshaw logo asset is dropped in.
class SlvLogoMark extends StatelessWidget {
  const SlvLogoMark({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'SLV',
        style: TextStyle(
          color: c.onPrimary,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
