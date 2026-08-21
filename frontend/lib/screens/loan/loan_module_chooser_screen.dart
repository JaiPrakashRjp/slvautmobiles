import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import 'loan_home_screen.dart';
import 'personal_loan_home_screen.dart';

/// Sub-chooser shown when the Loan module is opened: pick between the main
/// Loan Management System and Personal Loan Management.
class LoanModuleChooserScreen extends StatelessWidget {
  const LoanModuleChooserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Loan management')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.screenHPadding,
              vertical: AppSpacing.xl,
            ),
            children: [
              _LoanModuleCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Loan management system',
                subtitle: 'Loans against a vehicle — EMIs, reminders, seize.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoanHomeScreen()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LoanModuleCard(
                icon: Icons.person_outline,
                title: 'Personal loan management',
                subtitle: 'Simple monthly-EMI personal loans.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PersonalLoanHomeScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanModuleCard extends StatelessWidget {
  const _LoanModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: c.textSub)),
        ],
      ),
    );
  }
}
