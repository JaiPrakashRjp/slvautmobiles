import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/vehicle.dart';
import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/detail_field_card.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import 'rent_detail_screen.dart';
import 'rental_vehicle_form_screen.dart';

/// Read-only details for a rental vehicle: its fields, the current renter /
/// rental (with a link to the rent detail), and an edit pencil. Backed by the
/// real rental-scoped services (module = rental). Tapping a vehicle card opens
/// this (instead of jumping straight into the edit form).
class RentalVehicleDetailsScreen extends StatefulWidget {
  const RentalVehicleDetailsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<RentalVehicleDetailsScreen> createState() =>
      _RentalVehicleDetailsScreenState();
}

class _RentalVehicleDetailsScreenState
    extends State<RentalVehicleDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RentalVehicleService>().refresh();
      context.read<RentalAgreementService>().refresh();
      context.read<RentalCustomerService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vehicles = context.watch<RentalVehicleService>();
    final rentals = context.watch<RentalAgreementService>();
    final vehicle = vehicles.byId(widget.vehicleId);
    final auth = context.read<AuthController>();

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle detail')),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;
    final rental = rentals.forVehicle(vehicle.id);
    final renter = rental == null
        ? null
        : context.read<RentalCustomerService>().byId(rental.customerId);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Vehicle detail'),
        actions: [
          if (canModify)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit vehicle',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RentalVehicleFormScreen(existing: vehicle),
              )),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              ..._detailRows(vehicle),
              const SizedBox(height: AppSpacing.lg),
              Text('Rental',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),
              if (rental != null &&
                  rental.rentalStatus == 'active' &&
                  rental.isActive) ...[
                DetailFieldCard(
                    label: 'Current renter', value: renter?.fullName ?? '—'),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'View rental',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RentDetailScreen(rentalId: rental.id),
                  )),
                ),
              ] else
                const DetailFieldCard(
                    label: 'Current renter', value: 'Not currently rented'),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _detailRows(Vehicle v) {
    final rows = <Widget>[];
    void card(String label, {String? value, Widget? widget}) {
      if (widget == null && (value == null || value.isEmpty)) return;
      rows.add(DetailFieldCard(
          label: label, value: widget == null ? value : null, valueWidget: widget));
      rows.add(const SizedBox(height: AppSpacing.md));
    }

    card('Vehicle ID', value: v.displayId);
    card('Vehicle number', value: v.regNo.isEmpty ? '—' : v.regNo);
    card('Type', value: v.type.label);
    card('Model', value: v.model);
    card('Chassis number', value: v.chassisNo);
    card('Fuel type', value: v.fuelType?.label);
    card('Branch', value: v.branch?.label);
    card('RC', value: v.rc ? 'Yes' : 'No');
    card('Permit', value: v.permit ? 'Yes' : 'No');
    card('Insurance', value: v.insurance ? 'Yes' : 'No');
    if (v.insuranceDate != null) {
      card('Insurance date', value: Formatters.date(v.insuranceDate!));
    }
    if (v.fcDate != null) card('FC date', value: Formatters.date(v.fcDate!));
    if (v.permitDate != null) {
      card('Permit date', value: Formatters.date(v.permitDate!));
    }
    card('Status', widget: StatusPill.forEntity(v.status));
    card('Remarks', value: v.remarks);
    return rows;
  }
}
