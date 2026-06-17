import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/api_notification_service.dart';
import '../services/sale_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/responsive.dart';
import '../viewmodels/sign_in_viewmodel.dart';
import '../widgets/app_text_field.dart';
import 'module_chooser_screen.dart';

/// Sign-in screen — matches mockup 01-login.png.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignInViewModel(context.read<AuthController>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView();

  Future<void> _onSubmit(BuildContext context) async {
    final vm = context.read<SignInViewModel>();
    final feed = context.read<NotificationFeed>();
    final sales = context.read<SaleService>();
    final ok = await vm.submit();
    if (ok && context.mounted) {
      unawaited(feed.refresh());
      unawaited(sales.refresh());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ModuleChooserScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<SignInViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('SLV Auto Consultant')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 460,
          phone: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.screenHPadding,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.huge),
                Image.asset(
                  'assets/SLV logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Sign in', style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in to continue',
                  style: AppTextStyles.body.copyWith(color: c.textSub),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: vm.emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: vm.passwordController,
                  obscureText: vm.obscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      vm.obscure ? Icons.visibility_off : Icons.visibility,
                      color: c.textSub,
                      size: 20,
                    ),
                    onPressed: vm.toggleObscure,
                  ),
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      vm.error!,
                      style: AppTextStyles.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _SignInButton(
                  loading: vm.loading,
                  onPressed: () => _onSubmit(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  "Don't have an account? Contact Super admin",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: c.textSub),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('v1.0.0',
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A more premium sign-in button: navy gradient, soft branded shadow, and a
/// gold arrow accent. Falls back to a spinner while authenticating.
class _SignInButton extends StatefulWidget {
  const _SignInButton({required this.onPressed, required this.loading});

  final VoidCallback onPressed;
  final bool loading;

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.primary, c.primaryHover],
            ),
            borderRadius: BorderRadius.circular(AppRadius.button + 4),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: c.accent.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(c.onPrimary),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in',
                        style: TextStyle(
                          color: c.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 16, color: c.accent),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
