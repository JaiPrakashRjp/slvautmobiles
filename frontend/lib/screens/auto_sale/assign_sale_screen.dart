import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/customer_service.dart';
import '../../services/sale_financer_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../models/picked_doc.dart';
import '../../models/sale.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/assign_sale_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Sell a vehicle to a customer. Total is computed from the price breakdown;
/// full-cash vs down-payment is derived from the down payment.
class AssignSaleScreen extends StatefulWidget {
  const AssignSaleScreen({
    super.key,
    required this.customerId,
    this.initialVehicleId,
    this.existingSale,
  });

  final String customerId;
  final String? initialVehicleId;

  /// When set, the screen edits this existing sale instead of creating a new
  /// one (vehicle/customer are fixed; only the sale terms are editable).
  final Sale? existingSale;

  @override
  State<AssignSaleScreen> createState() => _AssignSaleScreenState();
}

class _AssignSaleScreenState extends State<AssignSaleScreen> {
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
        financers: context.read<SaleFinancerService>(),
        auth: context.read<AuthController>(),
        initialVehicleId: widget.initialVehicleId,
        existingSale: widget.existingSale,
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

  Future<void> _pickFinancer(BuildContext context, AssignSaleViewModel vm) async {
    final financerService = context.read<SaleFinancerService>();
    final messenger = ScaffoldMessenger.of(context);
    final financers = financerService.all();
    // -1 = add new, 0 = none, >0 = real financer id
    final options = [
      const SheetOption<int>(value: 0, label: '— None —'),
      const SheetOption<int>(value: -1, label: '＋ Add new financer'),
      ...financers.map((f) => SheetOption<int>(value: f.id, label: f.name)),
    ];
    final picked = await OptionSheet.show<int>(
      context,
      title: 'Financer',
      selected: vm.financerId ?? 0,
      options: options,
      searchable: financers.length > 5,
      searchHint: 'Search financer',
    );
    if (picked == null) return;
    if (picked == 0) {
      vm.financerId = null;
      return;
    }
    if (picked == -1) {
      if (!context.mounted) return;
      final nameCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add financer'),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Finance company name',
              hintText: 'e.g. HDFC Bank',
            ),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Add')),
          ],
        ),
      );
      if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
        try {
          final f = await financerService.create(nameCtrl.text.trim());
          vm.financerId = f.id;
        } catch (e) {
          messenger.showSnackBar(
              SnackBar(content: Text('Failed to add financer: $e')));
        }
      }
      nameCtrl.dispose();
      return;
    }
    vm.financerId = picked;
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
    final String msg;
    if (vm.isEditing) {
      msg = pending
          ? 'Edit submitted. Awaiting Super admin approval.'
          : 'Changes saved.';
    } else {
      msg = pending
          ? 'Submitted. Awaiting Super admin confirmation.'
          : 'Sale recorded.';
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<VehicleService>();
    final vm = context.watch<AssignSaleViewModel>();
    final customer = vm.customer;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
          title: Text(vm.isEditing ? 'Edit sale' : 'Customer - Sale')),
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
                    _InfoRow(label: 'Customer', value: customer?.fullName ?? '—', c: c),
                    if (customer != null && customer.phone.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                          label: 'Phone',
                          value: Formatters.phone(customer.phone),
                          c: c),
                    ],
                    if (vm.selectedVehicle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                          label: 'Vehicle',
                          value: vm.selectedVehicle!.displayLabel,
                          c: c),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Vehicle + financer pickers ────────────────────────────────
              PickerField(
                label: 'Assign vehicle',
                placeholder: 'Search vehicle',
                value: vm.selectedVehicle?.displayLabel,
                enabled: !vm.vehicleLocked,
                onTap: () => _pickVehicle(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Financer (optional)',
                placeholder: 'Select financer',
                value: vm.selectedFinancer?.name,
                onTap: () => _pickFinancer(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Amounts ───────────────────────────────────────────────────
              _SectionLabel('Amount details', c: c),
              const SizedBox(height: AppSpacing.md),
              _money(label: 'Vehicle amount', controller: vm.vehicleAmountController),
              const SizedBox(height: AppSpacing.md),
              _money(
                  label: 'Additional fitting',
                  controller: vm.additionalFittingController),
              const SizedBox(height: AppSpacing.md),
              _money(label: 'DL charges', controller: vm.dlChargesController),
              const SizedBox(height: AppSpacing.md),
              _money(
                  label: 'Document charges',
                  controller: vm.documentChargesController),
              const SizedBox(height: AppSpacing.md),
              _money(label: 'Other expenses', controller: vm.otherExpensesController),
              const SizedBox(height: AppSpacing.lg),

              // ── Total (read-only) ─────────────────────────────────────────
              _TotalCard(amount: vm.total, c: c),
              const SizedBox(height: AppSpacing.lg),

              // ── Down payment ──────────────────────────────────────────────
              _money(label: 'Down payment', controller: vm.downPaymentController),
              const SizedBox(height: AppSpacing.sm),
              if (vm.total > 0 && vm.downPayment > 0)
                _ModeHint(
                  isFullCash: vm.isFullCash,
                  remaining: vm.remaining,
                  c: c,
                ),

              // ── Loan-case fields (HP available to everyone, admins too) ───
              if (vm.showLoanFields) ...[
                const SizedBox(height: AppSpacing.lg),
                _money(label: 'HP amount (loan)', controller: vm.hpAmountController),
                const SizedBox(height: AppSpacing.md),
                // Remaining is derived: Total − HP − Down payment (read-only).
                _RemainingCard(amount: vm.remaining, c: c),
              ],
              const SizedBox(height: AppSpacing.lg),

              // ── Sale date / WhatsApp / remarks ────────────────────────────
              PickerField(
                label: 'Sale date',
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.saleDate == null ? null : Formatters.date(vm.saleDate!),
                onTap: () => _pickSaleDate(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Vehicle papers — saved onto the vehicle on Confirm ────────
              // Papers belong to the vehicle (not the gated sale edit), so they
              // are only captured when creating a sale, not when editing one.
              if (!vm.isEditing) ...[
                _SectionLabel('Vehicle papers', c: c),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Vehicle number',
                  hint: 'e.g. KA-01-AB-1234',
                  controller: vm.regNoController,
                ),
                const SizedBox(height: AppSpacing.md),
                _paperRow(context, vm, 'RC', 'rc', vm.rc, vm.rcDoc,
                    (v) => vm.rc = v),
                _paperRow(context, vm, 'Permit', 'permit', vm.permit,
                    vm.permitDoc, (v) => vm.permit = v),
                _paperRow(context, vm, 'Insurance', 'insurance', vm.insurance,
                    vm.insuranceDoc, (v) => vm.insurance = v),
                const SizedBox(height: AppSpacing.lg),
              ],

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
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Remarks',
                hint: 'Any notes about this sale',
                controller: vm.remarksController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),

              PrimaryButton(
                label: vm.loading
                    ? 'Saving…'
                    : (vm.isEditing ? 'Save changes' : 'Confirm sale'),
                onPressed: vm.loading ? null : () => _confirm(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A ₹ amount text field (digits only).
  Widget _money({
    required String label,
    required TextEditingController controller,
  }) {
    return AppTextField(
      label: label,
      prefixText: '₹ ',
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  /// One vehicle-paper row: a tick + an attach/change document button. Both the
  /// flag and the file are written onto the vehicle when the sale is confirmed.
  Widget _paperRow(
    BuildContext context,
    AssignSaleViewModel vm,
    String label,
    String wire,
    bool value,
    PickedDoc? doc,
    ValueChanged<bool> onToggle,
  ) {
    final c = context.colors;
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: c.primary,
          onChanged: (v) => onToggle(v ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.body.copyWith(color: c.textMain)),
              if (doc != null)
                Text(doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _pickPaper(context, vm, wire),
          icon: Icon(doc == null ? Icons.upload_file_outlined : Icons.check,
              size: 18),
          label: Text(doc == null ? 'Upload' : 'Change'),
        ),
      ],
    );
  }

  Future<void> _pickPaper(
      BuildContext context, AssignSaleViewModel vm, String wire) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Choose file'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final doc = source == 'photo' ? await pickPhotoDoc() : await pickFileDoc();
    if (doc != null) vm.setPaperDoc(wire, doc);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.c});
  final String text;
  final AppColors c;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.h2.copyWith(color: c.textMain));
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.amount, required this.c});
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
          Text('Total amount',
              style: AppTextStyles.label.copyWith(color: c.textSub)),
          const Spacer(),
          Text(Formatters.currency(amount),
              style: AppTextStyles.h2.copyWith(color: c.primary)),
        ],
      ),
    );
  }
}

/// Read-only card showing the derived installment balance (Total − HP − Down).
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
        color: c.bgContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderColor),
      ),
      child: Row(
        children: [
          Text('Remaining (installments)',
              style: AppTextStyles.label.copyWith(color: c.textSub)),
          const Spacer(),
          Text(Formatters.currency(amount),
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
        ],
      ),
    );
  }
}

/// Small line under the down payment telling the user the derived mode.
class _ModeHint extends StatelessWidget {
  const _ModeHint(
      {required this.isFullCash, required this.remaining, required this.c});
  final bool isFullCash;
  final int remaining;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final text = isFullCash
        ? 'Paid in full — full cash sale'
        : 'Down payment — balance ${Formatters.currency(remaining)}';
    return Row(
      children: [
        Icon(isFullCash ? Icons.check_circle_outline : Icons.account_balance_outlined,
            size: 16, color: isFullCash ? c.success : c.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppTextStyles.caption.copyWith(color: c.textSub)),
      ],
    );
  }
}
