import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/detail_field_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';

/// Admin detail — spec 6.2.3. Edit module access, verify, suspend, delete.
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final users = context.watch<UserService>();
    final user = users.byId(userId);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('User not found')),
      );
    }

    final modules = user.moduleAccess.toSet();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Admin detail')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: c.primaryContainer,
                      child: Text(
                        user.name.characters.first.toUpperCase(),
                        style: AppTextStyles.pageTitle.copyWith(color: c.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: AppTextStyles.pageTitle
                                  .copyWith(color: c.textMain)),
                          const SizedBox(height: 2),
                          Text(Formatters.phone(user.phone),
                              style: AppTextStyles.body
                                  .copyWith(color: c.textSub)),
                          if (user.email != null)
                            Text(user.email!,
                                style: AppTextStyles.caption
                                    .copyWith(color: c.textSub)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DetailFieldCard(
                label: 'Status',
                valueWidget: StatusPill(
                  label: user.status.label,
                  variant: switch (user.status) {
                    AccountStatus.active => PillVariant.success,
                    AccountStatus.suspended => PillVariant.danger,
                    _ => PillVariant.warning,
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DetailFieldCard(
                label: 'Joined',
                value: Formatters.date(user.createdAt),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Module access',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in const [
                    AppModule.autoSale,
                    AppModule.rentals,
                    // Loan management not launched yet (matches module chooser +
                    // create-user).
                    // AppModule.loans,
                  ])
                    GestureDetector(
                      onTap: () {
                        final next = modules.contains(m)
                            ? (modules.toList()..remove(m))
                            : (modules.toList()..add(m));
                        users.setModuleAccess(user.id, next);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: modules.contains(m)
                              ? c.primaryContainer
                              : c.bgContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: modules.contains(m) ? c.primary : c.borderColor,
                          ),
                        ),
                        child: Text(m.label,
                            style: AppTextStyles.body.copyWith(
                              color: modules.contains(m) ? c.primary : c.textMain,
                            )),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (user.status == AccountStatus.pendingVerification)
                PrimaryButton(
                  label: 'Verify admin',
                  icon: Icons.verified_outlined,
                  onPressed: () {
                    users.verify(user.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${user.name} verified.')),
                    );
                  },
                ),
              if (user.status == AccountStatus.active) ...[
                SecondaryButton(
                  label: 'Suspend',
                  onPressed: () => users.suspend(user.id),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Delete admin',
                danger: true,
                onPressed: () async {
                  final ok = await ConfirmationDialog.show(
                    context,
                    title: 'Delete admin',
                    message:
                        'Permanently remove ${user.name}? This cannot be undone.',
                    confirmLabel: 'Delete',
                    danger: true,
                  );
                  if (ok == true && context.mounted) {
                    users.delete(user.id);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
