import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../services/api_notification_service.dart';
import '../services/customer_service.dart';
import '../services/sale_service.dart';
import '../services/vehicle_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'auto_sale/customer_detail_screen.dart';
import 'auto_sale/sale_detail_screen.dart';
import 'auto_sale/vehicle_detail_screen.dart';
import 'users/pending_approvals_screen.dart';

/// Lists the signed-in user's in-app notifications (verification requests).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationFeed>().refresh();
    });
  }

  void _onTap(BuildContext context, NotificationItem n) {
    context.read<NotificationFeed>().markRead(n.id);

    if (n.type == 'verification_request') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()))
          .then((_) {
        // Refresh entity services so outcome pills reflect any just-made decisions.
        if (!context.mounted) return;
        context.read<VehicleService>().refresh();
        context.read<CustomerService>().refresh();
        context.read<SaleService>().refresh();
      });
      return;
    }

    if (n.entityId == null) return;
    final id = n.entityId.toString();
    switch (n.entityType) {
      case 'vehicle':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: id)),
        );
      case 'customer':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: id)),
        );
      case 'sale':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: id)),
        );
    }
  }

  /// Looks up the current approval status of the entity this notification refers to.
  EntityStatus? _entityStatus(BuildContext context, NotificationItem n) {
    if (n.entityId == null) return null;
    final id = n.entityId.toString();
    switch (n.entityType) {
      case 'vehicle':
        return context.read<VehicleService>().byId(id)?.status;
      case 'customer':
        return context.read<CustomerService>().byId(id)?.status;
      case 'sale':
        return context.read<SaleService>().byId(id)?.status;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feed = context.watch<NotificationFeed>();
    // Watch these so cards update live when super admin approves/rejects.
    context.watch<VehicleService>();
    context.watch<CustomerService>();
    context.watch<SaleService>();

    final items = feed.all();

    Widget body;
    if (feed.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = const EmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications',
        subtitle: 'Approval requests will appear here.',
      );
    } else {
      body = ListView(
        padding: EdgeInsets.all(context.screenHPadding),
        children: [
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _NotificationCard(
                n: n,
                entityStatus: _entityStatus(context, n),
                onTap: () => _onTap(context, n),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => feed.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: body,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.n,
    required this.onTap,
    this.entityStatus,
  });

  final NotificationItem n;
  final EntityStatus? entityStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Outcome pill based on current entity status.
    Widget? outcomePill;
    if (entityStatus != null) {
      outcomePill = switch (entityStatus!) {
        EntityStatus.active => _OutcomePill(
            label: 'Approved',
            color: c.success,
            icon: Icons.check_circle_outline,
          ),
        EntityStatus.rejected => _OutcomePill(
            label: 'Rejected',
            color: c.danger,
            icon: Icons.cancel_outlined,
          ),
        EntityStatus.pendingConfirmation => _OutcomePill(
            label: 'Waiting',
            color: c.warning,
            icon: Icons.hourglass_top_rounded,
          ),
      };
    }

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            n.isRead
                ? Icons.notifications_none
                : Icons.notifications_active,
            color: n.isRead ? c.textSub : c.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: c.textMain)),
                    ),
                    if (outcomePill != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      outcomePill,
                    ],
                  ],
                ),
                if (n.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.message,
                      style:
                          AppTextStyles.caption.copyWith(color: c.textSub)),
                ],
                const SizedBox(height: 4),
                Text(Formatters.date(n.createdAt),
                    style:
                        AppTextStyles.caption.copyWith(color: c.textSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
