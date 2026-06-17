import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../viewmodels/create_user_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

/// Create admin — spec 6.2.2.
class CreateUserScreen extends StatelessWidget {
  const CreateUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateUserViewModel(context.read<UserService>()),
      child: const _CreateUserView(),
    );
  }
}

class _CreateUserView extends StatelessWidget {
  const _CreateUserView();

  Future<void> _submit(BuildContext context, CreateUserViewModel vm) async {
    final error = vm.validate(phoneValidator: Validators.phone);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await vm.submit();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not create admin: $e')));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Admin created successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<CreateUserViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('New admin')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 500,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppTextField(label: 'Name', controller: vm.nameController),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Mobile number',
                prefixText: '+91 ',
                controller: vm.phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Email',
                controller: vm.emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              _PasswordField(vm: vm),
              const SizedBox(height: AppSpacing.lg),
              Text('Module access',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),
              for (final m in CreateUserViewModel.grantable)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ModuleCheck(
                    label: m.label,
                    checked: vm.modules.contains(m),
                    onChanged: (_) => vm.toggleModule(m),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(label: 'Create admin', onPressed: () => _submit(context, vm)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Password field with strength meter ─────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.vm});
  final CreateUserViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Set password for admin',
          controller: vm.passwordController,
          obscureText: vm.obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              vm.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: c.textSub,
            ),
            tooltip: vm.obscurePassword ? 'Show password' : 'Hide password',
            onPressed: vm.toggleObscurePassword,
          ),
        ),
        if (vm.passwordStrength != PasswordStrength.none) ...[
          const SizedBox(height: AppSpacing.sm),
          _StrengthBar(strength: vm.passwordStrength),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text('The admin will use this password to log in.',
            style: AppTextStyles.caption.copyWith(color: c.textSub)),
      ],
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color, filled) = switch (strength) {
      PasswordStrength.weak    => ('Weak',    const Color(0xFFD32F2F), 1),
      PasswordStrength.average => ('Average', const Color(0xFFF57C00), 2),
      PasswordStrength.strong  => ('Strong',  const Color(0xFF2E7D32), 3),
      PasswordStrength.none    => ('', Colors.transparent, 0),
    };

    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i < filled ? color : c.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: AppSpacing.xs),
        ],
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Module checkbox ─────────────────────────────────────────────────────────

class _ModuleCheck extends StatelessWidget {
  const _ModuleCheck({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: checked ? c.primaryContainer : c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: checked ? c.primary : c.borderColor),
        ),
        child: Row(
          children: [
            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                color: checked ? c.primary : c.textSub, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: AppTextStyles.body.copyWith(color: c.textMain)),
          ],
        ),
      ),
    );
  }
}
