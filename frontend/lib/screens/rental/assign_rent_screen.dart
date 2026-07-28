import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/rental_agreement.dart';
import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';

/// Rent a vehicle to a customer: total, advance, remaining (derived), start
/// date, remarks. Mirrors the sale assign screen, on the rental services.
class AssignRentScreen extends StatefulWidget {
  const AssignRentScreen({
    super.key,
    required this.customerId,
    required this.vehicleId,
    this.existing,
  });

  final String customerId;
  final String vehicleId;

  /// When set, the screen edits this rental instead of creating a new one
  /// (vehicle/customer fixed; only the terms change). Admin edit → super-admin
  /// approval; super admin → applies at once.
  final RentalAgreement? existing;

  @override
  State<AssignRentScreen> createState() => _AssignRentScreenState();
}

class _AssignRentScreenState extends State<AssignRentScreen> {
  final _totalCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime? _startDate = DateTime.now();
  bool _loading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _totalCtrl.text = e.totalAmount == 0 ? '' : '${e.totalAmount}';
      _advanceCtrl.text = e.advance == 0 ? '' : '${e.advance}';
      _remarksCtrl.text = e.remarks ?? '';
      _startDate = e.startDate;
    }
    _totalCtrl.addListener(() => setState(() {}));
    _advanceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _advanceCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  int get _total => int.tryParse(_totalCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _advance => int.tryParse(_advanceCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _remaining => (_total - _advance).clamp(0, 1 << 31);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _confirm() async {
    if (_loading) return;
    if (_total <= 0) {
      _snack('Enter the total rent amount');
      return;
    }
    if (_advance > _total) {
      _snack('Advance cannot exceed the total');
      return;
    }
    setState(() => _loading = true);
    final rentals = context.read<RentalAgreementService>();
    final vehicles = context.read<RentalVehicleService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final remarks =
        _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim();
    try {
      if (_isEditing) {
        final pending = await rentals.editRental(
          widget.existing!.id,
          totalAmount: _total,
          advance: _advance,
          startDate: _startDate,
          remarks: remarks,
        );
        navigator.pop();
        messenger.showSnackBar(SnackBar(
          content: Text(pending
              ? 'Edit submitted. Awaiting Super admin approval.'
              : 'Changes saved.'),
        ));
        return;
      }
      final rental = await rentals.create(
        vehicleId: widget.vehicleId,
        customerId: widget.customerId,
        totalAmount: _total,
        advance: _advance,
        startDate: _startDate,
        remarks: remarks,
      );
      await vehicles.refresh();
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(rental.isPending
            ? 'Submitted. Awaiting Super admin confirmation.'
            : 'Vehicle rented.'),
      ));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(
          content: Text('Could not ${_isEditing ? 'save' : 'rent'}: $e')));
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customer = context.read<RentalCustomerService>().byId(widget.customerId);
    final vehicle = context.read<RentalVehicleService>().byId(widget.vehicleId);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: Text(_isEditing ? 'Edit rental' : 'Rent vehicle')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 520,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _info('Customer', customer?.fullName ?? '—', c),
                    if (customer != null && customer.phone.isNotEmpty)
                      _info('Phone', Formatters.phone(customer.phone), c),
                    if (vehicle != null)
                      _info(
                          'Vehicle',
                          vehicle.regNo.isNotEmpty
                              ? vehicle.regNo
                              : (vehicle.chassisNo ?? '—'),
                          c),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _money('Total rent amount', _totalCtrl),
              const SizedBox(height: AppSpacing.md),
              _money('Advance received', _advanceCtrl),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.bgContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.borderColor),
                ),
                child: Row(
                  children: [
                    Text('Remaining',
                        style: AppTextStyles.label.copyWith(color: c.textSub)),
                    const Spacer(),
                    Text(Formatters.currency(_remaining),
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Purchase date',
                leadingIcon: Icons.calendar_today_outlined,
                placeholder: 'Select date',
                value: _startDate == null ? null : Formatters.date(_startDate!),
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Remarks',
                hint: 'Any notes about this rental',
                controller: _remarksCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: _loading
                    ? 'Saving…'
                    : (_isEditing ? 'Save changes' : 'Confirm rent'),
                onPressed: _loading ? null : _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _money(String label, TextEditingController ctrl) => AppTextField(
        label: label,
        prefixText: '₹ ',
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      );

  Widget _info(String label, String value, AppColors c) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 76,
                child: Text(label,
                    style: AppTextStyles.caption.copyWith(color: c.textSub))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(value,
                    style: AppTextStyles.body.copyWith(color: c.textMain))),
          ],
        ),
      );
}
