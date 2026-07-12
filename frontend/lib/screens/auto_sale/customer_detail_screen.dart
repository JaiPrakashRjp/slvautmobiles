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
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';
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
        .where((s) => s.saleStatus != 'cancelled' && !s.isRejected)
        .toList();

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

              // ── Documents (view + share) ──────────────────────────────────
              if (customer.uploadedDocs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Documents',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < customer.uploadedDocs.length; i++) ...[
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.description_outlined,
                              color: c.primary),
                          title: Text(
                              _kycLabel(customer.uploadedDocs[i].docTypeWire)),
                          subtitle: Text(customer.uploadedDocs[i].fileName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.visibility_outlined),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DocumentPreviewScreen(
                                title: _kycLabel(
                                    customer.uploadedDocs[i].docTypeWire),
                                fileName: customer.uploadedDocs[i].fileName,
                                loader: () => customers.documentBytes(
                                    customer.uploadedDocs[i].id),
                              ),
                            ),
                          ),
                        ),
                        if (i != customer.uploadedDocs.length - 1)
                          Divider(height: 1, color: c.borderColor),
                      ],
                    ],
                  ),
                ),
              ],

              // ── Vehicles & sales (a customer can have several) ────────────
              const SizedBox(height: AppSpacing.lg),
              Text('Vehicles & sales',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),

              if (customerSales.isEmpty)
                AppCard(
                  child: Text('No sales yet.',
                      style: AppTextStyles.body.copyWith(color: c.textSub)),
                )
              else
                for (final sale in customerSales) ...[
                  AppCard(
                    accentLeft: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SaleDetailScreen(saleId: sale.id),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicles.byId(sale.vehicleId)?.regNo ?? 'Vehicle',
                                style: AppTextStyles.bodyStrong
                                    .copyWith(color: c.textMain),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  sale.saleStatus,
                                  if (sale.salePrice != null)
                                    Formatters.currency(sale.salePrice!),
                                ].join(' · '),
                                style: AppTextStyles.caption
                                    .copyWith(color: c.textSub),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: c.textSub),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

              const SizedBox(height: AppSpacing.sm),
              // Sell a vehicle to this customer (works for the 1st and additional).
              if (customer.isActive && canModify)
                PrimaryButton(
                  label: customerSales.isEmpty
                      ? 'Assign vehicle & sale'
                      : 'Sell another vehicle',
                  icon: Icons.sell_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AssignSaleScreen(customerId: customerId),
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

/// Friendly label for a KYC document's backend type wire.
String _kycLabel(String wire) {
  switch (wire) {
    case 'aadhaar':
      return 'Aadhaar';
    case 'pan':
      return 'PAN';
    case 'dl':
      return 'Driving licence';
    case 'photo':
      return 'Photo';
    case 'rental_agreement':
      return 'Rental agreement';
    case 'assurity_id_proof':
      return 'Assurity ID proof';
    default:
      return wire.replaceAll('_', ' ');
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
