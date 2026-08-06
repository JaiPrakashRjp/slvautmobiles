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

/// Rent a vehicle to a customer on a recurring basis: rental type (weekly/daily),
/// per-period rent, advance (recorded only), rental date, remarks. The first rent
/// reminder is scheduled one interval after the rental date; each payment rolls
/// the next one forward. Admin edit → super-admin approval; super admin → applies
/// at once.
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
  /// (vehicle/customer fixed; only the terms change).
  final RentalAgreement? existing;

  @override
  State<AssignRentScreen> createState() => _AssignRentScreenState();
}

class _AssignRentScreenState extends State<AssignRentScreen> {
  final _rentCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _type = 'weekly'; // 'weekly' | 'daily'
  DateTime? _startDate = DateTime.now();
  bool _loading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.rentalType ?? 'weekly';
      _rentCtrl.text = e.periodAmount == 0 ? '' : '${e.periodAmount}';
      _advanceCtrl.text = e.advance == 0 ? '' : '${e.advance}';
      _remarksCtrl.text = e.remarks ?? '';
      _startDate = e.startDate;
    }
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _advanceCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  int get _rent => int.tryParse(_rentCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  int get _advance => int.tryParse(_advanceCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

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
    if (_rent <= 0) {
      _snack('Enter the rent amount');
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
          rentalType: _type,
          periodAmount: _rent,
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
        rentalType: _type,
        periodAmount: _rent,
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
    final rentLabel = _type == 'weekly' ? 'Weekly rent' : 'Daily rent';

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
              Text('Rental type',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'weekly',
                      label: Text('Weekly'),
                      icon: Icon(Icons.calendar_view_week_outlined)),
                  ButtonSegment(
                      value: 'daily',
                      label: Text('Daily'),
                      icon: Icon(Icons.today_outlined)),
                ],
                selected: {_type},
                // Locked once the rental exists — a reminder is already scheduled
                // on this cadence. End the rental to switch type.
                onSelectionChanged:
                    _isEditing ? null : (s) => setState(() => _type = s.first),
              ),
              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Rental type can’t be changed after the rental starts.',
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
              ],
              const SizedBox(height: AppSpacing.lg),
              _money(rentLabel, _rentCtrl),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _type == 'weekly'
                    ? 'Reminder every 7 days from the rental date until paid.'
                    : 'Reminder every day from the rental date until paid.',
                style: AppTextStyles.caption.copyWith(color: c.textSub),
              ),
              const SizedBox(height: AppSpacing.md),
              _money('Advance received', _advanceCtrl),
              const SizedBox(height: AppSpacing.lg),
              PickerField(
                label: 'Rental date',
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
