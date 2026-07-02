import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/customer.dart';
import '../../models/doc_ref.dart';
import '../../services/customer_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/customers_list_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/page_size_picker.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'create_customer_screen.dart';
import 'customer_detail_screen.dart';

/// Customers list — mockup 07.
class CustomersListScreen extends StatelessWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomersListViewModel(
        context.read<CustomerService>(),
        context.read<VehicleService>(),
        context.read<AuthController>(),
      ),
      child: const _CustomersListView(),
    );
  }
}

class _CustomersListView extends StatelessWidget {
  const _CustomersListView();

  Future<void> _openCreate(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateCustomerScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customers = context.watch<CustomerService>();
    context.watch<VehicleService>();
    final vm = context.watch<CustomersListViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Auto sale system'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to modules',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          GoldCreateButton(iconOnly: true, onPressed: () => _openCreate(context)),
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
                  index: vm.tab,
                  onChanged: (i) => vm.tab = i,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                    context.screenHPadding, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (q) {
                          final t = q.trim();
                          vm.search(t.length >= 4 ? t : '');
                        },
                        decoration: InputDecoration(
                          hintText: 'Search name / phone…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PageSizePicker(
                        value: vm.pageSize, onChanged: (v) => vm.pageSize = v),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final vel = d.primaryVelocity ?? 0;
                    if (vel < -250 && vm.tab == 0) vm.tab = 1;
                    if (vel > 250 && vm.tab == 1) vm.tab = 0;
                  },
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final vehicleSvc = context.read<VehicleService>();
                      await customers.refresh();
                      await vehicleSvc.refresh();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                          context.screenHPadding, AppSpacing.xl),
                      children: [
                        if (customers.loading && vm.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyState(
                              icon: Icons.people_outline,
                              title: vm.tab == 0
                                  ? 'No customers with a vehicle'
                                  : 'No customers without a vehicle',
                              subtitle: 'Tap “+” to add a customer.',
                              ctaLabel: 'Add customer',
                              onCta: () => _openCreate(context),
                            ),
                          )
                        else ...[
                          for (final cust in vm.pageItems)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _CustomerCard(customer: cust, vm: vm),
                            ),
                          if (vm.totalPages > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: vm.page > 0
                                      ? () => vm.setPage(vm.page - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('Page ${vm.page + 1} of ${vm.totalPages}'),
                                IconButton(
                                  onPressed: vm.page < vm.totalPages - 1
                                      ? () => vm.setPage(vm.page + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                        ],
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.vm});

  final Customer customer;
  final CustomersListViewModel vm;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete customer',
      message: 'Remove ${customer.fullName}? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) vm.delete(customer.id);
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(customerId: customer.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final customers = context.read<CustomerService>();
    final canModify =
        auth.isSuperAdmin || customer.createdBy == auth.currentUser?.id;
    final photoRef = customer.uploadedDocs
        .where((d) => d.docTypeWire == 'photo')
        .cast<DocRef?>()
        .firstOrNull;
    return AppCard(
      onTap: () => _open(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Photo ─────────────────────────────────────────────────
          CircleAvatar(
            radius: 22,
            backgroundColor: c.bgSurface,
            backgroundImage: photoRef == null
                ? null
                : NetworkImage(customers.documentUrl(photoRef.id)),
            child: photoRef == null
                ? Icon(Icons.person_outline, color: c.textSub)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(customer.fullName,
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                    const SizedBox(width: AppSpacing.sm),
                    StatusPill.forEntity(customer.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(Formatters.phone(customer.phone),
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
              ],
            ),
          ),
          // ── Icons (top-right, horizontal with spacing) ─────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View customer',
                onPressed: () => _open(context),
              ),
              if (canModify) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButtonSoft(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateCustomerScreen(existing: customer),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButtonSoft(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  danger: true,
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
