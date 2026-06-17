import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../widgets/slv_logo_mark.dart';
import 'module_chooser_screen.dart';
import 'sign_in_screen.dart';

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
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    final signedIn = context.read<AuthController>().isSignedIn;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            signedIn ? const ModuleChooserScreen() : const SignInScreen(),
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
