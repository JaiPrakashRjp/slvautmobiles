import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/assign_rental_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/tab_bar_navy.dart';

/// Assign rental — mockup 12. Optionally pre-filled with a renter.
class AssignRentalScreen extends StatelessWidget {
  const AssignRentalScreen({super.key, this.customerId});

  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssignRentalViewModel(
        customerId: customerId,
        rentals: context.read<RentalService>(),
        auth: context.read<AuthController>(),
      ),
      child: const _AssignRentalView(),
    );
  }
}

class _AssignRentalView extends StatelessWidget {
  const _AssignRentalView();

  Future<void> _pickRenter(BuildContext context, AssignRentalViewModel vm) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select renter',
      selected: vm.customerId,
      options: vm.renters
          .map((r) => SheetOption(
                value: r.id,
                label: r.fullName,
                subtitle: Formatters.phone(r.phone),
              ))
          .toList(),
    );
    if (picked != null) vm.customerId = picked;
  }

  Future<void> _pickVehicle(
      BuildContext context, AssignRentalViewModel vm) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select vehicle',
      selected: vm.vehicleId,
      options: vm.availableVehicles
          .map((v) => SheetOption(value: v.id, label: v.regNo))
          .toList(),
    );
    if (picked != null) vm.vehicleId = picked;
  }

  Future<void> _pickStart(BuildContext context, AssignRentalViewModel vm) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.startDate ?? DateTime(2026, 6, 3),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) vm.startDate = picked;
  }

  void _confirm(BuildContext context, AssignRentalViewModel vm) {
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
            : 'Rental assigned.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<RentalService>();
    final vm = context.watch<AssignRentalViewModel>();
    final customer = vm.customer;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Assign rental')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              if (vm.needsRenterPick)
                PickerField(
                  label: 'Renter',
                  placeholder: 'Select renter',
                  value: null,
                  onTap: () => _pickRenter(context, vm),
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer',
                          style: AppTextStyles.body.copyWith(color: c.textSub)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(customer?.fullName ?? '—',
                          style: AppTextStyles.h2.copyWith(color: c.textMain)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: c.success),
                          const SizedBox(width: 4),
                          Text('Verified',
                              style: AppTextStyles.label
                                  .copyWith(color: c.success)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Select vehicle',
                placeholder: 'Select vehicle',
                value: vm.selectedVehicle?.regNo,
                onTap: () => _pickVehicle(context, vm),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Rental basis',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.xs),
              TabBarNavy(
                tabs: const ['Daily', 'Weekly', 'Monthly'],
                index: RentalBasis.values.indexOf(vm.basis),
                onChanged: (i) => vm.basis = RentalBasis.values[i],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: vm.rentLabel,
                prefixText: '₹ ',
                hint: '2,000 ${vm.rentSuffix}',
                controller: vm.rentController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Start date',
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: vm.startDate == null
                    ? null
                    : Formatters.date(vm.startDate!),
                onTap: () => _pickStart(context, vm),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Confirm rental',
                onPressed: () => _confirm(context, vm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
