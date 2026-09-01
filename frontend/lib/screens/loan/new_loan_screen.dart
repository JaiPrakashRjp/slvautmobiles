import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/loan.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/new_loan_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';
import '../auto_sale/create_customer_screen.dart';

/// New loan — no interest. Pick a loan customer + loan vehicle, then enter the
/// loan date, loan amount, tenure (months) and EMI amount.
class NewLoanScreen extends StatelessWidget {
  const NewLoanScreen(
      {super.key, this.customerId, this.vehicleId, this.editLoan});

  /// Pre-selected customer (opened from a customer's detail).
  final String? customerId;

  /// Pre-selected vehicle (opened from a vehicle's "Assign loan").
  final String? vehicleId;

  /// When set, the screen edits this existing loan (within its 5-hour window)
  /// instead of booking a new one — saving rebuilds its EMI schedule.
  final Loan? editLoan;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewLoanViewModel(
        context.read<LoanService>(),
        context.read<LoanCustomerService>(),
        context.read<LoanVehicleService>(),
        context.read<AuthController>(),
        initialCustomerId: customerId,
        initialVehicleId: vehicleId,
        editLoan: editLoan,
      ),
      child: const _NewLoanView(),
    );
  }
}

class _NewLoanView extends StatelessWidget {
  const _NewLoanView();

  Future<void> _pickCustomer(BuildContext context, NewLoanViewModel vm) async {
    final navigator = Navigator.of(context);
    final loanCustomers = context.read<LoanCustomerService>();
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select customer',
      selected: vm.customerId,
      options: [
        const SheetOption(value: '__add__', label: '＋ Add new customer'),
        ...vm.verifiedCustomers.map((c) => SheetOption(
              value: c.id,
              label: c.fullName,
              subtitle: Formatters.phone(c.phone),
            )),
      ],
    );
    if (picked == null) return;
    if (picked == '__add__') {
      // Create a new loan customer inline, then select it on return.
      final newId = await navigator.push<String>(MaterialPageRoute(
        builder: (_) => CreateCustomerScreen(
          service: loanCustomers,
          extendedAssurity: true,
          returnOnCreate: true,
        ),
      ));
      if (newId != null) vm.customerId = newId;
      return;
    }
    vm.customerId = picked;
  }

  Future<void> _pickVehicle(BuildContext context, NewLoanViewModel vm) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select vehicle',
      selected: vm.vehicleId,
      options: vm.availableVehicles
          .map((v) => SheetOption(
                value: v.id,
                label: v.displayLabel,
                subtitle: v.model ?? '',
              ))
          .toList(),
    );
    if (picked != null) vm.vehicleId = picked;
  }

  Future<void> _pickDate(BuildContext context, NewLoanViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.loanDate ?? DateTime(2026, 6, 5),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked != null) vm.loanDate = picked;
  }

  Future<void> _submit(BuildContext context, NewLoanViewModel vm) async {
    final error = vm.validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // Editing rebuilds the schedule; warn first if payments would be wiped.
    if (vm.isEdit && vm.editHasPayments) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overwrite the schedule?'),
          content: const Text(
              'This loan already has recorded payments. Saving these changes '
              'will rebuild the EMI schedule and permanently remove all '
              'payments recorded so far. This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final isEdit = vm.isEdit;
    final pending = vm.submit();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit
            ? 'Loan updated.'
            : pending
                ? 'Submitted. Awaiting Super admin confirmation.'
                : 'Loan created.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<NewLoanViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: Text(vm.isEdit ? 'Edit loan' : 'New loan')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              PickerField(
                label: 'Customer',
                required: true,
                placeholder: 'Select customer',
                value: vm.customer?.fullName,
                onTap: () => _pickCustomer(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Vehicle',
                required: true,
                leadingIcon: Icons.electric_rickshaw,
                placeholder: 'Select the loan vehicle',
                value: vm.vehicle?.displayLabel,
                onTap: () => _pickVehicle(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Loan date',
                required: true,
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.loanDate == null
                    ? null
                    : Formatters.date(vm.loanDate!),
                onTap: () => _pickDate(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Loan amount',
                required: true,
                prefixText: '₹ ',
                controller: vm.principalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Tenure (months)',
                      required: true,
                      controller: vm.tenureController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => vm.refreshPreview(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'EMI amount',
                      required: true,
                      prefixText: '₹ ',
                      controller: vm.emiController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => vm.refreshPreview(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _TotalPreview(vm: vm),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: vm.isEdit ? 'Save changes' : 'Create loan',
                onPressed: () => _submit(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview({required this.vm});

  final NewLoanViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vm.emiAmount <= 0 || vm.tenure <= 0) return const SizedBox.shrink();

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppTextStyles.body
                      .copyWith(color: c.onPrimary.withValues(alpha: 0.8))),
              Text(value,
                  style: TextStyle(
                    color: c.onPrimary,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    fontSize: strong ? 18 : 14,
                  )),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schedule preview',
              style: AppTextStyles.label.copyWith(color: c.accent)),
          const SizedBox(height: AppSpacing.sm),
          row('Monthly EMI', Formatters.currency(vm.emiAmount), strong: true),
          row('Months', '${vm.tenure}'),
          row('Total repayable', Formatters.currency(vm.totalPayable)),
        ],
      ),
    );
  }
}
