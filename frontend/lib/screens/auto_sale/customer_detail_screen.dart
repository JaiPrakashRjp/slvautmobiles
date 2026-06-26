import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/customer_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import 'assign_sale_screen.dart';
import 'create_customer_screen.dart';
import 'sale_detail_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<CustomerService>();
    context.watch<SaleService>();
    context.watch<VehicleService>();

    final customers = context.read<CustomerService>();
    final sales = context.read<SaleService>();
    final vehicles = context.read<VehicleService>();
    final auth = context.read<AuthController>();

    final customer = customers.byId(customerId);
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer detail')),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final customerSales = sales
        .forCustomer(customerId)
        .where((s) => s.saleStatus != 'cancelled')
        .toList();
    final activeSale = customerSales.isEmpty ? null : customerSales.first;
    final vehicle = activeSale == null
        ? null
        : vehicles.byId(activeSale.vehicleId);

    final canModify =
        auth.isSuperAdmin || customer.createdBy == auth.currentUser?.id;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Customer detail'),
        actions: [
          if (canModify)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateCustomerScreen(existing: customer),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              // ── Gate banner ───────────────────────────────────────────────
              if (!customer.isActive) ...[
                RoleGateBanner(
                  status: customer.status,
                  rejectionReason: customer.rejectionReason,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Customer info card ────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(customer.fullName,
                              style:
                                  AppTextStyles.h2.copyWith(color: c.textMain)),
                        ),
                        StatusPill.forEntity(customer.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _Row(label: 'Phone',
                        value: Formatters.phone(customer.phone), c: c),
                    if (customer.address.isNotEmpty)
                      _Row(label: 'Address', value: customer.address, c: c),
                    if (customer.branch != null)
                      _Row(label: 'Branch', value: customer.branch!.label, c: c),
                    if (customer.age != null)
                      _Row(label: 'Age', value: '${customer.age}', c: c),
                    if (customer.remarks != null &&
                        customer.remarks!.isNotEmpty)
                      _Row(label: 'Remarks', value: customer.remarks!, c: c),
                  ],
                ),
              ),

              // ── Assurity person ───────────────────────────────────────────
              if (customer.assurityName != null &&
                  customer.assurityName!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Assurity person',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: 'Name',
                          value: customer.assurityName!, c: c),
                      if (customer.assurityMobile != null &&
                          customer.assurityMobile!.isNotEmpty)
                        _Row(
                            label: 'Mobile',
                            value: Formatters.phone(customer.assurityMobile!),
                            c: c),
                    ],
                  ),
                ),
              ],

              // ── Assigned vehicle / sale ───────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              Text('Vehicle & sale',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),

              if (activeSale == null)
                AppCard(
                  child: Text('No active sale.',
                      style: AppTextStyles.body.copyWith(color: c.textSub)),
                )
              else
                AppCard(
                  accentLeft: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                          label: 'Vehicle',
                          value: vehicle?.regNo ?? '—',
                          c: c),
                      _Row(
                          label: 'Deposit',
                          value: activeSale.depositType.label,
                          c: c),
                      if (activeSale.saleDate != null)
                        _Row(
                            label: 'Sale date',
                            value: Formatters.date(activeSale.saleDate!),
                            c: c),
                      if (activeSale.salePrice != null)
                        _Row(
                            label: 'Total price',
                            value: Formatters.currency(activeSale.salePrice!),
                            c: c),
                      _Row(
                          label: 'Sale status',
                          value: activeSale.saleStatus,
                          c: c),
                      if (activeSale.unsellReason != null &&
                          activeSale.unsellReason!.isNotEmpty)
                        _Row(
                            label: 'Unsell reason',
                            value: activeSale.unsellReason!,
                            c: c),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // ── Action buttons ────────────────────────────────────────────
              if (activeSale != null)
                SecondaryButton(
                  label: 'View sale detail',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SaleDetailScreen(saleId: activeSale.id),
                    ),
                  ),
                )
              else if (customer.isActive && canModify)
                PrimaryButton(
                  label: 'Assign vehicle & sale',
                  icon: Icons.sell_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AssignSaleScreen(customerId: customerId),
                    ),
                  ),
                ),

              // ── Role-gate approve / reject ────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              RoleGateActions(
                status: customer.status,
                onApprove: () {
                  customers.confirm(
                      customer.id, auth.currentUser?.id ?? 'u_super');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer approved.')),
                  );
                },
                onReject: (reason) {
                  customers.reject(
                      customer.id, reason, auth.currentUser?.id ?? 'u_super');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer rejected.')),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.c});
  final String label;
  final String value;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value,
                style: AppTextStyles.body.copyWith(color: c.textMain)),
          ),
        ],
      ),
    );
  }
}
