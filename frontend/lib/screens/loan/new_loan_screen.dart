import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../services/customer_service.dart';
import '../../services/loan_service.dart';
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
import '../../widgets/tab_bar_navy.dart';

/// New loan — spec 8.7.3, single form with a live EMI preview.
class NewLoanScreen extends StatelessWidget {
  const NewLoanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewLoanViewModel(
        context.read<LoanService>(),
        context.read<CustomerService>(),
        context.read<AuthController>(),
      ),
      child: const _NewLoanView(),
    );
  }
}

class _NewLoanView extends StatelessWidget {
  const _NewLoanView();

  Future<void> _pickCustomer(BuildContext context, NewLoanViewModel vm) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select customer',
      selected: vm.customerId,
      options: vm.verifiedCustomers
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle: Formatters.phone(c.phone),
              ))
          .toList(),
    );
    if (picked != null) vm.customerId = picked;
  }

  Future<void> _pickDate(BuildContext context, NewLoanViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.disbursementDate ?? DateTime(2026, 6, 2),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) vm.disbursementDate = picked;
  }

  void _submit(BuildContext context, NewLoanViewModel vm) {
    final error = vm.validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final pending = vm.submit();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pending
            ? 'Submitted. Awaiting Super admin confirmation.'
            : 'Loan created. Agreement will be generated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vm = context.watch<NewLoanViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('New loan')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              PickerField(
                label: 'Customer',
                placeholder: 'Select customer',
                value: vm.customer?.fullName,
                onTap: () => _pickCustomer(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Principal',
                prefixText: '₹ ',
                controller: vm.principalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => vm.refreshPreview(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Interest rate (% / yr)',
                      controller: vm.rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => vm.refreshPreview(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Tenure (months)',
                      controller: vm.tenureController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => vm.refreshPreview(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Disbursement date',
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.disbursementDate == null
                    ? null
                    : Formatters.date(vm.disbursementDate!),
                onTap: () => _pickDate(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Penalty rule',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.xs),
              TabBarNavy(
                tabs: const ['Flat ₹/day', '% of EMI/day'],
                index: vm.penaltyType == PenaltyType.flatPerDay ? 0 : 1,
                onChanged: (i) => vm.penaltyType =
                    i == 0 ? PenaltyType.flatPerDay : PenaltyType.percentPerDay,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: vm.penaltyType == PenaltyType.flatPerDay
                    ? 'Penalty (₹ per day)'
                    : 'Penalty (% of EMI per day)',
                controller: vm.penaltyValueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.xl),
              _EmiPreview(vm: vm),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Create loan',
                onPressed: () => _submit(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmiPreview extends StatelessWidget {
  const _EmiPreview({required this.vm});

  final NewLoanViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (vm.principal <= 0 || vm.tenure <= 0 || vm.rate <= 0) {
      return const SizedBox.shrink();
    }
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
          row('Total interest', Formatters.currency(vm.totalInterest)),
          row('Total payable', Formatters.currency(vm.totalPayable)),
        ],
      ),
    );
  }
}
