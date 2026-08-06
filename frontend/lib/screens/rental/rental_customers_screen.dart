import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/customer.dart';
import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import '../auto_sale/create_customer_screen.dart';
import 'rental_customer_rentals_screen.dart';

/// Rental customers — the rental module's own independent customer list
/// (module = rental). Same create / edit / KYC / approval functionality as the
/// sale customers, wired to the rental-scoped [RentalCustomerService].
class RentalCustomersScreen extends StatefulWidget {
  const RentalCustomersScreen({super.key});

  @override
  State<RentalCustomersScreen> createState() => _RentalCustomersScreenState();
}

class _RentalCustomersScreenState extends State<RentalCustomersScreen> {
  String _query = '';
  int _tab = 0; // 0 = With vehicle, 1 = Without vehicle

  @override
  void initState() {
    super.initState();
    // Auto-refresh on open so newly-added customers / approvals + their rentals
    // show (rentals decide the With / Without vehicle split).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RentalCustomerService>().refresh();
      context.read<RentalAgreementService>().refresh();
    });
  }

  Future<void> _openCreate(BuildContext context) {
    final service = context.read<RentalCustomerService>();
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateCustomerScreen(service: service),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customers = context.watch<RentalCustomerService>();
    final rentals = context.watch<RentalAgreementService>();

    // A customer "has a vehicle" only while a rental is currently ACTIVE. Once
    // the rental ends (completed/seized), the customer moves to Without-vehicle
    // (their rental history is still kept on their profile).
    final withVehicleIds = <String>{
      for (final r in rentals.all())
        if (r.rentalStatus == 'active' && r.isActive) r.customerId,
    };

    final q = _query.trim().toLowerCase();
    final list = customers.all().where((cust) {
      final hasVehicle = withVehicleIds.contains(cust.id);
      if (_tab == 0 ? !hasVehicle : hasVehicle) return false;
      if (q.isEmpty) return true;
      return cust.fullName.toLowerCase().contains(q) ||
          cust.phone.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Auto rental system'),
        automaticallyImplyLeading: false,
        actions: [
          GoldCreateButton(
            iconOnly: true,
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.lg, context.screenHPadding, AppSpacing.md),
                child: TabBarNavy(
                  tabs: const ['With vehicle', 'Without vehicle'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                    context.screenHPadding, AppSpacing.sm),
                child: TextField(
                  onChanged: (v) => setState(
                      () => _query = v.trim().length >= 3 ? v : ''),
                  decoration: InputDecoration(
                    hintText: 'Search name / phone…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final vel = d.primaryVelocity ?? 0;
                    if (vel < -250 && _tab == 0) setState(() => _tab = 1);
                    if (vel > 250 && _tab == 1) setState(() => _tab = 0);
                  },
                  child: RefreshIndicator(
                  onRefresh: customers.refresh,
                  child: (customers.loading && list.isEmpty)
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 60),
                                EmptyState(
                                  icon: Icons.people_outline,
                                  title: _tab == 0
                                      ? 'No customers with a vehicle'
                                      : 'No customers without a vehicle',
                                  subtitle: 'Tap “+” to add a customer.',
                                  ctaLabel: 'Add customer',
                                  onCta: () => _openCreate(context),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                  context.screenHPadding,
                                  0,
                                  context.screenHPadding,
                                  AppSpacing.xl),
                              children: [
                                for (final cust in list)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.lg),
                                    child: _RentalCustomerCard(customer: cust),
                                  ),
                              ],
                            ),
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

class _RentalCustomerCard extends StatelessWidget {
  const _RentalCustomerCard({required this.customer});

  final Customer customer;

  Future<void> _edit(BuildContext context) {
    final service = context.read<RentalCustomerService>();
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateCustomerScreen(existing: customer, service: service),
    ));
  }

  Future<void> _openDetail(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RentalCustomerRentalsScreen(customerId: customer.id),
    ));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final service = context.read<RentalCustomerService>();
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete customer',
      message: 'Remove ${customer.fullName}? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) service.delete(customer.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final service = context.read<RentalCustomerService>();
    final actorId = auth.currentUser?.id ?? '';
    final canModify = auth.isSuperAdmin || customer.createdBy == actorId;
    final canReview = auth.isSuperAdmin && customer.isPending;

    return AppCard(
      onTap: () => _openDetail(context),
      accentLeft: customer.isRejected,
      accentColor: customer.isRejected ? c.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: c.bgSurface,
                child: Icon(Icons.person_outline, color: c.textSub),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        Text(customer.fullName,
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain)),
                        StatusPill.forEntity(customer.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CallChip(phone: customer.phone),
                    ),
                    if (customer.isRejected &&
                        (customer.rejectionReason?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Rejected: ${customer.rejectionReason}',
                          style:
                              AppTextStyles.caption.copyWith(color: c.danger)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final reason = await ConfirmationDialog.show(
                        context,
                        title: 'Reject customer',
                        message: 'Give the staff member a reason.',
                        confirmLabel: 'Reject',
                        danger: true,
                        requireReason: true,
                      );
                      if (reason is String && reason.isNotEmpty) {
                        service.reject(customer.id, reason, actorId);
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => service.confirm(customer.id, actorId),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: c.borderColor),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View rentals',
                compact: true,
                onPressed: () => _openDetail(context),
              ),
              if (canModify) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButtonSoft(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  compact: true,
                  onPressed: () => _edit(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButtonSoft(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  danger: true,
                  compact: true,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
