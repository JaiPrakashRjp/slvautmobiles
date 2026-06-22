import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../services/customer_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/assign_sale_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Assign vehicle + payment to a customer.
class AssignSaleScreen extends StatefulWidget {
  const AssignSaleScreen({
    super.key,
    required this.customerId,
    this.initialVehicleId,
  });

  final String customerId;
  final String? initialVehicleId;

  @override
  State<AssignSaleScreen> createState() => _AssignSaleScreenState();
}

class _AssignSaleScreenState extends State<AssignSaleScreen> {
  // Stable key stored in state — survives rebuilds (keyboard, MediaQuery, etc.)
  // but is unique per route push, so stale data never carries over.
  final _providerKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: _providerKey,
      create: (_) => AssignSaleViewModel(
        customerId: widget.customerId,
        customers: context.read<CustomerService>(),
        vehicles: context.read<VehicleService>(),
        sales: context.read<SaleService>(),
        auth: context.read<AuthController>(),
        initialVehicleId: widget.initialVehicleId,
      ),
      child: const _AssignSaleView(),
    );
  }
}

class _AssignSaleView extends StatelessWidget {
  const _AssignSaleView();

  Future<void> _pickVehicle(BuildContext context, AssignSaleViewModel vm) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Assign vehicle',
      searchable: true,
      searchHint: 'Search by reg number',
      selected: vm.vehicleId,
      options: vm.availableVehicles
          .map((v) => SheetOption(
                value: v.id,
                label: v.displayLabel,
                subtitle: v.type.label,
              ))
          .toList(),
    );
    if (picked != null) vm.vehicleId = picked;
  }

  Future<void> _pickDeposit(BuildContext context, AssignSaleViewModel vm) async {
    final picked = await OptionSheet.show<DepositType>(
      context,
      title: 'Deposit type',
      selected: vm.depositType,
      options: DepositType.values
          .map((d) => SheetOption(value: d, label: d.label))
          .toList(),
    );
    if (picked != null) vm.depositType = picked;
  }

  Future<void> _pickSaleDate(BuildContext context, AssignSaleViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.saleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) vm.saleDate = picked;
  }

  Future<void> _pickFirstDue(BuildContext context, AssignSaleViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.firstDueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) vm.firstDueDate = picked;
  }

  Future<void> _confirm(BuildContext context, AssignSaleViewModel vm) async {
    final error = vm.validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final bool pending;
    try {
      pending = await vm.submit();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save sale: $e')));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(pending
            ? 'Submitted. Awaiting Super admin confirmation.'
            : 'Sale recorded.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<VehicleService>();
    final vm = context.watch<AssignSaleViewModel>();
    final customer = vm.customer;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Customer - Sale')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              // ── Sale info card ────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Module',
                      value: AppModule.autoSale.label,
                      c: c,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Customer',
                      value: customer?.fullName ?? '—',
                      c: c,
                    ),
                    if (customer != null && customer.phone.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        label: 'Phone',
                        value: Formatters.phone(customer.phone),
                        c: c,
                      ),
                    ],
                    if (vm.selectedVehicle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        label: 'Vehicle',
                        value: vm.selectedVehicle!.displayLabel,
                        c: c,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Vehicle picker ────────────────────────────────────────────
              PickerField(
                label: 'Assign vehicle',
                placeholder: 'Search vehicle',
                value: vm.selectedVehicle?.displayLabel,
                enabled: !vm.vehicleLocked,
                onTap: () => _pickVehicle(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Deposit type ──────────────────────────────────────────────
              PickerField(
                label: 'Deposit type',
                placeholder: 'Select deposit type',
                value: vm.depositType.label,
                onTap: () => _pickDeposit(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Total sale price (always shown) ───────────────────────────
              AppTextField(
                label: 'Total sale price',
                prefixText: '₹ ',
                controller: vm.totalSalePriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Down payment extra fields ─────────────────────────────────
              if (vm.depositType == DepositType.downPayment) ...[
                AppTextField(
                  label: 'Advance received',
                  prefixText: '₹ ',
                  controller: vm.advanceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.md),
                // Remaining — computed read-only
                _RemainingCard(amount: vm.remaining, c: c),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Monthly amount',
                        prefixText: '₹ ',
                        controller: vm.monthlyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Number of months',
                        controller: vm.monthsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PickerField(
                  label: 'First installment due date',
                  leadingIcon: Icons.calendar_today_outlined,
                  placeholder: 'Select date',
                  value: vm.firstDueDate == null
                      ? null
                      : Formatters.date(vm.firstDueDate!),
                  onTap: () => _pickFirstDue(context, vm),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Sale date (always shown) ───────────────────────────────────
              PickerField(
                label: 'Sale date',
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.saleDate == null
                    ? null
                    : Formatters.date(vm.saleDate!),
                onTap: () => _pickSaleDate(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Customer WhatsApp ─────────────────────────────────────────
              AppTextField(
                label: 'Customer WhatsApp',
                hint: '10-digit mobile number',
                controller: vm.whatsappController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              PrimaryButton(
                label: vm.loading ? 'Saving…' : 'Confirm sale',
                onPressed:
                    vm.loading ? null : () => _confirm(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.c});
  final String label;
  final String value;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label,
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(value,
              style: AppTextStyles.body.copyWith(color: c.textMain)),
        ),
      ],
    );
  }
}

class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.amount, required this.c});
  final int amount;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text('Remaining',
              style: AppTextStyles.label.copyWith(color: c.textSub)),
          const Spacer(),
          Text(Formatters.currency(amount),
              style: AppTextStyles.bodyStrong.copyWith(color: c.primary)),
        ],
      ),
    );
  }
}
