import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/vehicles_list_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/page_size_picker.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'assign_sale_screen.dart';
import 'create_customer_screen.dart';
import 'create_vehicle_screen.dart';
import 'vehicle_detail_screen.dart';

/// Vehicles list — mockup 04. Assigned / Unassigned tabs with paginated cards.
class VehiclesListScreen extends StatelessWidget {
  const VehiclesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VehiclesListViewModel(
        context.read<VehicleService>(),
        context.read<AuthController>(),
        context.read<SaleService>(),
        context.read<CustomerService>(),
      ),
      child: const _VehiclesListView(),
    );
  }
}

class _VehiclesListView extends StatelessWidget {
  const _VehiclesListView();

  Future<void> _openCreate(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateVehicleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Rebuild when the underlying vehicle data changes.
    final vehicles = context.watch<VehicleService>();
    // Rebuild cards when sales change so the "Pending" badge appears/clears live.
    context.watch<SaleService>();
    // Rebuild when customers load so the sold-vehicle owner name/phone shows.
    context.watch<CustomerService>();
    final vm = context.watch<VehiclesListViewModel>();

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
                  tabs: const ['Not sold', 'Sold'],
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
                          hintText: 'Search chassis / reg no / model…',
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
                    if (vel < -250 && vm.tab == 0) vm.tab = 1; // swipe left → next
                    if (vel > 250 && vm.tab == 1) vm.tab = 0; // swipe right → prev
                  },
                  child: RefreshIndicator(
                    onRefresh: () => vehicles.refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                          context.screenHPadding, AppSpacing.xl),
                      children: [
                        if (vehicles.loading && vm.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyState(
                              title: vm.tab == 0
                                  ? 'No unsold vehicles'
                                  : 'No sold vehicles',
                              subtitle: 'Tap “Create” to add an auto-rickshaw.',
                              ctaLabel: 'Create vehicle',
                              onCta: () => _openCreate(context),
                            ),
                          )
                        else ...[
                          for (final v in vm.pageItems)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _VehicleCard(vehicle: v, vm: vm),
                            ),
                          if (vm.totalPages > 1) _Pager(vm: vm),
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.vm});

  final Vehicle vehicle;
  final VehiclesListViewModel vm;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete vehicle',
      message: 'Remove ${vehicle.regNo} from inventory? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) vm.delete(vehicle.id);
  }

  void _openDetail(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id),
        ),
      );

  /// Sell this vehicle: pick a verified customer (searchable), then open the
  /// sale screen with the vehicle pre-selected.
  Future<void> _sell(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final customers = context.read<CustomerService>();
    // Show active AND pending customers (not rejected). A pending one is marked
    // and can't be sold to until the super admin approves it.
    final listable =
        customers.all().where((c) => c.isActive || c.isPending).toList();
    final customerId = await OptionSheet.show<String>(
      context,
      title: 'Sell to customer',
      searchable: true,
      searchHint: 'Search by name or phone',
      addLabel: 'New customer',
      // "+" → create a new customer, then go straight to the sell form.
      onAdd: () => navigator.push(MaterialPageRoute(
        builder: (_) => CreateCustomerScreen(sellVehicleId: vehicle.id),
      )),
      options: listable
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle: c.isActive
                    ? c.phone
                    : '${c.phone}  ·  Pending approval',
              ))
          .toList(),
    );
    if (customerId == null) return;
    // Block selling to a still-pending customer.
    final chosen = customers.byId(customerId);
    if (chosen != null && !chosen.isActive) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'This customer is still pending approval. You can sell once it is approved.'),
      ));
      return;
    }
    await navigator.push(MaterialPageRoute(
      builder: (_) => AssignSaleScreen(
        customerId: customerId,
        initialVehicleId: vehicle.id,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    // A sale awaiting super-admin approval keeps the vehicle in "Not sold" with
    // a Pending badge; it only moves to Sold once approved.
    final hasPendingSale = context
        .read<SaleService>()
        .all()
        .any((s) => s.vehicleId == vehicle.id && s.isPending);
    // An admin may only modify what they created; super-admin records are
    // view-only for them. Super admin can do anything.
    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;
    final canSell = canModify &&
        vehicle.isActive &&
        vehicle.saleStatus == SaleStatus.notSold &&
        !hasPendingSale;
    return AppCard(
      onTap: () => _openDetail(context),
      accentLeft: vehicle.isRejected,
      accentColor: vehicle.isRejected ? c.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top: details + status (full width) ────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: 4,
                children: [
                  Text(
                      (vehicle.chassisNo?.isNotEmpty ?? false)
                          ? vehicle.chassisNo!
                          : vehicle.displayLabel,
                      style: AppTextStyles.h2.copyWith(color: c.textMain)),
                  if (vehicle.isSeized)
                    const StatusPill(
                        label: 'Seized', variant: PillVariant.danger)
                  else if (hasPendingSale)
                    const StatusPill(
                        label: 'Pending', variant: PillVariant.warning)
                  else
                    StatusPill.forEntity(vehicle.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(vehicle.type.label,
                  style: AppTextStyles.body.copyWith(color: c.textSub)),
              // Sold vehicle → show the buyer's name + a tappable call chip.
              if (vm.owner(vehicle) != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Flexible(
                      child: Text(vm.owner(vehicle)!.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: c.textMain)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    CallChip(phone: vm.owner(vehicle)!.phone),
                  ],
                ),
              ],
              if (vehicle.isRejected &&
                  (vehicle.rejectionReason?.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Rejected: ${vehicle.rejectionReason}',
                    style: AppTextStyles.caption.copyWith(color: c.danger)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: c.borderColor),
          const SizedBox(height: AppSpacing.sm),
          // ── Below: small action icons, right-aligned ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                compact: true,
                onPressed: () => _openDetail(context),
              ),
              if (canSell) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButtonSoft(
                  icon: Icons.sell_outlined,
                  tooltip: 'Sell',
                  compact: true,
                  onPressed: () => _sell(context),
                ),
              ],
              // Delete only for an independent vehicle (never part of any sale);
              // a vehicle with sale history keeps the record, so no delete.
              if (canModify && !vm.hasSale(vehicle.id)) ...[
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

class _Pager extends StatelessWidget {
  const _Pager({required this.vm});

  final VehiclesListViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < vm.totalPages; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => vm.setPage(i),
                child: Container(
                  height: 40,
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == vm.page ? c.primary : c.bgSurface,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: c.borderColor),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTextStyles.body.copyWith(
                      color: i == vm.page ? c.onPrimary : c.textSub,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
