import 'package:flutter/material.dart';

/// Global navigator key so background notification taps can push routes
/// without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
