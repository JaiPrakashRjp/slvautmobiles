import 'package:flutter/material.dart';

/// Removes the default desktop/web scrollbar and the Android overscroll glow,
/// for the clean edge-to-edge lists shown in the mockups. Applied via
/// `ScrollConfiguration` (see main.dart) or per-scrollable as needed.
class NoScrollbarBehavior extends MaterialScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
