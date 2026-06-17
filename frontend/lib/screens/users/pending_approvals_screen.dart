import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/rental_service.dart';
import '../../services/sale_service.dart';
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

/// A single pending action awaiting Super Admin confirmation.
class _PendingItem {
  _PendingItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.onApprove,
    required this.onReject,
  });

  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;
}

/// Super Admin review queue — spec 5.5. Aggregates pending items from every
/// module, oldest first.
class PendingApprovalsScreen extends StatelessWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final actorId = context.read<AuthController>().currentUser?.id ?? 'u_super';

    final customers = context.watch<CustomerService>();
    final vehicles = context.watch<VehicleService>();
    final sales = context.watch<SaleService>();
    final rentals = context.watch<RentalService>();
    final loans = context.watch<LoanService>();

    String custName(String id) =>
        customers.byId(id)?.fullName ??
        rentals.renterById(id)?.fullName ??
        'customer';

    final items = <_PendingItem>[];

    for (final v in vehicles.all().where((v) => v.isPending)) {
      items.add(_PendingItem(
        type: 'Vehicle',
        title: 'Vehicle ${v.regNo}',
        subtitle: 'Added by ${v.createdBy}',
        createdAt: v.createdAt,
        onApprove: () => vehicles.confirm(v.id, actorId),
        onReject: (r) => vehicles.reject(v.id, r, actorId),
      ));
    }
    for (final cust in customers.all().where((c) => c.isPending)) {
      items.add(_PendingItem(
        type: 'Customer',
        title: 'Customer ${cust.fullName}',
        subtitle: 'Added by ${cust.createdBy}',
        createdAt: cust.createdAt,
        onApprove: () => customers.confirm(cust.id, actorId),
        onReject: (r) => customers.reject(cust.id, r, actorId),
      ));
    }
    for (final s in sales.all().where((s) => s.isPending)) {
      items.add(_PendingItem(
        type: 'Sale',
        title: 'Sale to ${custName(s.customerId)}',
        subtitle: 'Added by ${s.createdBy}',
        createdAt: s.createdAt,
        onApprove: () => sales.confirm(s.id, actorId),
        onReject: (r) => sales.reject(s.id, r, actorId),
      ));
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
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.task_alt,
                title: 'Nothing to review',
                subtitle: 'Admin actions awaiting your confirmation show up here.',
              )
            : ResponsiveBody(
                maxFormWidth: 720,
                phone: ListView(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.type,
                style: AppTextStyles.caption.copyWith(color: c.primary)),
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
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Approve',
                  onPressed: item.onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
