import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_notification_service.dart';
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
    // Refresh on open (fire-and-forget; the feed notifies when done).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationFeed>().refresh();
    });
  }

  void _onTap(BuildContext context, NotificationItem n) {
    context.read<NotificationFeed>().markRead(n.id);

    // Verification requests → go to the approval queue.
    if (n.type == 'verification_request') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
      );
      return;
    }

    // Info / other notifications → deep-link to the specific entity.
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final feed = context.watch<NotificationFeed>();
    final items = feed.all();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  title: 'No notifications',
                  subtitle: 'Approval requests will appear here.',
                )
              : ListView(
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    for (final n in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          onTap: () => _onTap(context, n),
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
                                    Text(n.title,
                                        style: AppTextStyles.bodyStrong
                                            .copyWith(color: c.textMain)),
                                    if (n.message.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(n.message,
                                          style: AppTextStyles.caption
                                              .copyWith(color: c.textSub)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(Formatters.date(n.createdAt),
                                        style: AppTextStyles.caption
                                            .copyWith(color: c.textSub)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
