import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/rental_service.dart';
import '../../services/sale_service.dart';
import '../../services/user_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../auto_sale/customer_detail_screen.dart';
import '../auto_sale/sale_detail_screen.dart';
import '../auto_sale/vehicle_detail_screen.dart';

/// A single pending action awaiting Super Admin confirmation.
class _PendingItem {
  _PendingItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.onApprove,
    required this.onReject,
    this.onView,
  });

  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;

  /// Opens the full detail screen so the reviewer can verify before deciding.
  final VoidCallback? onView;
}

/// Super Admin review queue — spec 5.5. Aggregates pending items from every
/// module, oldest first.
class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() =>
      _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  // True while the first fetch on open is in flight (shows a spinner instead of
  // a misleading empty state).
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Auto-refresh on open so newly-submitted items (an admin's sale/seize) show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  /// Re-pull the gated entities from the server. Backs both the auto-refresh on
  /// open and pull-to-refresh (slide down).
  Future<void> _refresh() async {
    await Future.wait([
      context.read<CustomerService>().refresh(),
      context.read<VehicleService>().refresh(),
      context.read<SaleService>().refresh(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final actorId = context.read<AuthController>().currentUser?.id ?? 'u_super';

    final customers = context.watch<CustomerService>();
    final vehicles = context.watch<VehicleService>();
    final sales = context.watch<SaleService>();
    final rentals = context.watch<RentalService>();
    final loans = context.watch<LoanService>();
    final users = context.read<UserService>();

    String custName(String id) =>
        customers.byId(id)?.fullName ??
        rentals.renterById(id)?.fullName ??
        'customer';

    // Resolve the creating admin's name; fall back to the raw id if unknown.
    String addedBy(String createdBy) =>
        'Added by ${users.byId(createdBy)?.name ?? createdBy}';

    final items = <_PendingItem>[];

    for (final v in vehicles.all().where((v) => v.isPending)) {
      items.add(_PendingItem(
        type: 'Vehicle',
        title: 'Vehicle ${v.regNo}',
        subtitle: addedBy(v.createdBy),
        createdAt: v.createdAt,
        onApprove: () => vehicles.confirm(v.id, actorId),
        onReject: (r) => vehicles.reject(v.id, r, actorId),
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VehicleDetailScreen(vehicleId: v.id),
        )),
      ));
    }
    for (final cust in customers.all().where((c) => c.isPending)) {
      items.add(_PendingItem(
        type: 'Customer',
        title: 'Customer ${cust.fullName}',
        subtitle: addedBy(cust.createdBy),
        createdAt: cust.createdAt,
        onApprove: () => customers.confirm(cust.id, actorId),
        onReject: (r) => customers.reject(cust.id, r, actorId),
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(customerId: cust.id),
        )),
      ));
    }
    for (final s in sales.all().where((s) => s.isPending)) {
      items.add(_PendingItem(
        type: 'Sale',
        title: 'Sale to ${custName(s.customerId)}',
        subtitle: addedBy(s.createdBy),
        createdAt: s.createdAt,
        onApprove: () => sales.confirm(s.id, actorId),
        onReject: (r) => sales.reject(s.id, r, actorId),
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SaleDetailScreen(saleId: s.id),
        )),
      ));
    }
    // Pending vehicle seizes requested by an admin.
    for (final s in sales.all().where((s) => s.isSeizePending)) {
      items.add(_PendingItem(
        type: 'Seize',
        title: 'Seize · ${custName(s.customerId)}',
        subtitle: s.seizedBy != null
            ? 'Requested by ${users.byId(s.seizedBy!)?.name ?? s.seizedBy}'
            : 'Seize requested',
        createdAt: s.seizedAt ?? s.createdAt,
        onApprove: () async {
          await sales.approveSeize(s.id);
          await vehicles.refresh();
        },
        onReject: (r) => sales.rejectSeize(s.id, r),
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SaleDetailScreen(saleId: s.id),
        )),
      ));
    }
    // Pending payments (manual + installment) submitted by an admin.
    for (final s in sales.all()) {
      for (final p in s.payments.where((p) => p.isPending)) {
        items.add(_PendingItem(
          type: 'Payment',
          title: 'Payment · ${custName(s.customerId)}',
          subtitle:
              '${Formatters.currency(p.amount)} · ${p.isManual ? 'Manual' : 'Installment'}',
          createdAt: p.paidAt ?? s.createdAt,
          onApprove: () => sales.approvePayment(s.id, p.id),
          onReject: (r) => sales.declinePayment(s.id, p.id, r),
          onView: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SaleDetailScreen(saleId: s.id),
          )),
        ));
      }
    }
    for (final r in rentals.pendingRentals()) {
      items.add(_PendingItem(
        type: 'Rental',
        title: 'Rental for ${custName(r.customerId)}',
        subtitle: '${r.basis.label} · ${Formatters.currency(r.rent)}',
        createdAt: r.createdAt,
        onApprove: () => rentals.confirmRental(r.id, actorId),
        onReject: (reason) => rentals.rejectRental(r.id, reason, actorId),
      ));
    }
    for (final l in loans.all().where((l) => l.isPending)) {
      items.add(_PendingItem(
        type: 'Loan',
        title: 'Loan for ${custName(l.customerId)}',
        subtitle:
            '${Formatters.currency(l.principal)} · ${l.tenureMonths} mo · added by ${l.createdBy}',
        createdAt: l.createdAt,
        onApprove: () => loans.confirm(l.id, actorId),
        onReject: (reason) => loans.reject(l.id, reason, actorId),
      ));
    }

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Pending approvals')),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
          onRefresh: _refresh,
          child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.task_alt,
                    title: 'Nothing to review',
                    subtitle:
                        'Admin actions awaiting your confirmation show up here.',
                  ),
                ],
              )
            : ResponsiveBody(
                maxFormWidth: 720,
                phone: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    Text(
                      '${items.length} item${items.length == 1 ? '' : 's'} awaiting confirmation',
                      style: AppTextStyles.body.copyWith(color: c.textSub),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _PendingCard(item: item),
                      ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.item});

  final _PendingItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      accentLeft: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.type,
                    style: AppTextStyles.caption.copyWith(color: c.primary)),
              ),
              const Spacer(),
              if (item.onView != null)
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View full details',
                  visualDensity: VisualDensity.compact,
                  onPressed: item.onView,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.title,
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
          const SizedBox(height: 2),
          Text(item.subtitle,
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
          const SizedBox(height: 2),
          Text(Formatters.relative(item.createdAt, now: DateTime(2026, 6, 2)),
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  danger: true,
                  onPressed: () async {
                    final reason = await ConfirmationDialog.show(
                      context,
                      title: 'Reject ${item.type.toLowerCase()}',
                      message: 'Give the staff member a reason.',
                      confirmLabel: 'Reject',
                      danger: true,
                      requireReason: true,
                    );
                    if (reason is String && reason.isNotEmpty) {
                      item.onReject(reason);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.type} rejected.')),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Approve',
                  onPressed: () {
                    item.onApprove();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.type} approved.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
