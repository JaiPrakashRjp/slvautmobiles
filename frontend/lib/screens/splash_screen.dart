import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/app_version_service.dart';
import '../services/local_push_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../widgets/slv_logo_mark.dart';
import 'module_chooser_screen.dart';
import 'sign_in_screen.dart';

/// Fixed id for the "update available" push (kept far from the notification
/// feed's ids, which reuse small backend notification ids).
const _kUpdateNotificationId = 900001;

/// Branded splash; routes to module chooser when signed in, else to sign-in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Restore a saved 24-hour session (if any) while the splash animation plays.
    final restoreFuture = context.read<AuthController>().restore();
    // Check for a newer published build too.
    final updateFuture = AppVersionService().check();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await restoreFuture;
    final update = await updateFuture;

    // Newer version out → fire a system-tray push; tapping it opens login.
    if (update != null && update.updateAvailable) {
      unawaited(LocalPushService.show(
        id: _kUpdateNotificationId,
        title: update.mandatory ? 'Update required' : 'Update available',
        body: 'Version ${update.latest} is ready. Tap to update.',
        payload: kUpdatePayload,
      ));
    }

    if (!mounted) return;
    final signedIn = context.read<AuthController>().isSignedIn;
    // When an update is available, always land on login (where the update gate
    // blocks sign-in until the user updates); otherwise route as usual.
    final showLogin = (update?.updateAvailable ?? false) || !signedIn;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            showLogin ? const SignInScreen() : const ModuleChooserScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SlvLogoMark(size: 140),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'SLV Auto Consultant',
              style: TextStyle(
                color: c.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(c.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
