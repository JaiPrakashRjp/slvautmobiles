import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// import '../../controllers/auth_controller.dart'; // hidden: Run reminders button
import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/reminder_log.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/status_pill.dart';
import 'create_user_screen.dart';
// import 'pending_approvals_screen.dart'; // hidden: Pending approvals button
import 'user_detail_screen.dart';

/// User management — spec 6.2.1. Super Admin only.
class UsersHomeScreen extends StatelessWidget {
  const UsersHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // final auth = context.read<AuthController>(); // hidden: Run reminders button
    final users = context.watch<UserService>();
    final admins = users.admins();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('User management'),
        actions: [
          // Hidden for this release — Run WhatsApp reminders & Pending approvals.
          // if (auth.isSuperAdmin) const _RunRemindersButton(),
          // IconButton(
          //   icon: const Icon(Icons.fact_check_outlined),
          //   tooltip: 'Pending approvals',
          //   onPressed: () => Navigator.of(context).push(
          //     MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
          //   ),
          // ),
          GoldCreateButton(
            label: 'New admin',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateUserScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: admins.isEmpty
              ? const EmptyState(
                  icon: Icons.group_outlined,
                  title: 'No staff yet',
                  subtitle: 'Add an admin to help run the business.',
                )
              : ListView(
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    for (final a in admins)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _AdminCard(admin: a),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Run reminders button (super admin only) ───────────────────────────────────

class _RunRemindersButton extends StatefulWidget {
  const _RunRemindersButton();

  @override
  State<_RunRemindersButton> createState() => _RunRemindersButtonState();
}

class _RunRemindersButtonState extends State<_RunRemindersButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ApiClient();
      final data = await api.post('/reminders/run');
      if (!mounted) return;
      final logs = (data as List)
          .map((j) => ReminderLog.fromJson(j as Map<String, dynamic>))
          .toList();

      if (logs.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('No reminders due right now.')));
        return;
      }

      // Show sheet; user can open each WhatsApp link from there
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RemindersSheet(
          logs: logs,
          notif: context.read<NotificationService>(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Reminders failed: $e')));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Run WhatsApp reminders',
      icon: _running
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      onPressed: _running ? null : _run,
    );
  }
}

// ── Reminders result bottom sheet ─────────────────────────────────────────────

class _RemindersSheet extends StatelessWidget {
  const _RemindersSheet({required this.logs, required this.notif});

  final List<ReminderLog> logs;
  final NotificationService notif;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: c.bgCanvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${logs.length} reminder(s) due',
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: logs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, i) =>
                    _ReminderItem(log: logs[i], notif: notif),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ReminderItem extends StatefulWidget {
  const _ReminderItem({required this.log, required this.notif});
  final ReminderLog log;
  final NotificationService notif;

  @override
  State<_ReminderItem> createState() => _ReminderItemState();
}

class _ReminderItemState extends State<_ReminderItem> {
  bool _sent = false;

  Future<void> _send() async {
    await widget.notif.send(
      phone: widget.log.recipientPhone,
      message: widget.log.message,
    );
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final log = widget.log;
    final label = log.recipientType == 'super_admin' ? 'Super admin' : 'Customer';
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: _sent ? c.success : c.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label  ·  ${log.recipientPhone}',
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${Formatters.date(log.dueDate)}',
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  log.message,
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _sent
              ? Icon(Icons.check_circle, color: c.success, size: 20)
              : TextButton(
                  onPressed: _send,
                  child: const Text('Send'),
                ),
        ],
      ),
    );
  }
}

// ── Admin card ────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.admin});

  final AppUser admin;

  (String, PillVariant) get _status => switch (admin.status) {
        AccountStatus.active => ('Active', PillVariant.success),
        AccountStatus.pendingVerification =>
          ('Pending verification', PillVariant.warning),
        AccountStatus.pendingProfile => ('Pending profile', PillVariant.info),
        AccountStatus.suspended => ('Suspended', PillVariant.danger),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, variant) = _status;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserDetailScreen(userId: admin.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.primaryContainer,
                child: Text(
                  admin.name.characters.first.toUpperCase(),
                  style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name,
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                    Text(Formatters.phone(admin.phone),
                        style:
                            AppTextStyles.caption.copyWith(color: c.textSub)),
                  ],
                ),
              ),
              StatusPill(label: label, variant: variant),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in admin.moduleAccess)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.bgCanvas,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: c.borderColor),
                  ),
                  child: Text(m.label,
                      style: AppTextStyles.caption.copyWith(color: c.textSub)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
