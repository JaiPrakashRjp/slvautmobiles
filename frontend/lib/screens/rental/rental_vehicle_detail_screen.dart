import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';

/// Rental vehicle detail — mockups 16 (Details), 17 (Customers), 18 (Rentals).
class RentalVehicleDetailScreen extends StatefulWidget {
  const RentalVehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<RentalVehicleDetailScreen> createState() =>
      _RentalVehicleDetailScreenState();
}

class _RentalVehicleDetailScreenState extends State<RentalVehicleDetailScreen> {
  int _tab = 0;
  static final DateTime _now = DateTime(2026, 6, 2);

  String _rangeLabel(Rental r) {
    final mon = DateFormat('MMM', 'en_IN');
    if (r.rentalStatus == 'active') {
      return 'Since ${Formatters.date(r.startDate)}';
    }
    final end = r.endDate;
    if (end == null) return Formatters.date(r.startDate);
    final sameYear = end.year == r.startDate.year;
    return sameYear
        ? '${mon.format(r.startDate)} – ${mon.format(end)} ${end.year}'
        : '${mon.format(r.startDate)} ${r.startDate.year} – ${mon.format(end)} ${end.year}';
  }

  String _durationLabel(Rental r) {
    final n = r.collections.where((c) => c.isPaid).length;
    final unit = switch (r.basis) {
      RentalBasis.daily => 'day',
      RentalBasis.weekly => 'week',
      RentalBasis.monthly => 'month',
    };
    return '$n $unit${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalService>();
    final vehicle = rentals.vehicleById(widget.vehicleId);

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle detail')),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final history = rentals.rentalsForVehicle(widget.vehicleId);
    final activeRental = rentals.activeRentalForVehicle(widget.vehicleId);
    final isRented = vehicle.inventoryStatus == InventoryStatus.onRent;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Vehicle detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Editing arrives with the edit flow.')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle.regNo,
                              style:
                                  AppTextStyles.h2.copyWith(color: c.textMain)),
                          const SizedBox(height: 2),
                          Text('Bajaj RE · Three-wheeler',
                              style: AppTextStyles.body
                                  .copyWith(color: c.textSub)),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: isRented ? 'Rented' : 'Available',
                      variant:
                          isRented ? PillVariant.success : PillVariant.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TabBarNavy(
                tabs: const ['Details', 'Customers', 'Rentals'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_tab == 0)
                _DetailsTab(
                  vehicle: vehicle,
                  rental: activeRental,
                  now: _now,
                  onEnd: activeRental == null
                      ? null
                      : () async {
                          final ok = await ConfirmationDialog.show(
                            context,
                            title: 'End rental',
                            message: 'End the rental on ${vehicle.regNo}?',
                            confirmLabel: 'End rental',
                            danger: true,
                          );
                          if (ok == true) rentals.endRental(activeRental.id);
                        },
                )
              else if (_tab == 1)
                _CustomersTab(
                  rentals: history,
                  rangeLabel: _rangeLabel,
                  resolveName: (r) =>
                      rentals.renterById(r.customerId)?.fullName ?? '—',
                )
              else
                _RentalsTab(
                  rentals: history,
                  rangeLabel: _rangeLabel,
                  durationLabel: _durationLabel,
                  resolveName: (r) =>
                      rentals.renterById(r.customerId)?.fullName ?? '—',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.vehicle,
    required this.rental,
    required this.now,
    required this.onEnd,
  });

  final dynamic vehicle;
  final Rental? rental;
  final DateTime now;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.read<RentalService>();
    final renter =
        rental == null ? null : rentals.renterById(rental!.customerId);
    final serviceDue = vehicle.nextServiceDueDate as DateTime?;
    final daysToService =
        serviceDue == null ? null : Formatters.daysUntil(serviceDue, now: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current renter',
            style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
        const SizedBox(height: AppSpacing.md),
        if (rental == null)
          AppCard(
            child: Text('Not currently rented',
                style: AppTextStyles.body.copyWith(color: c.textSub)),
          )
        else
          AppCard(
            accentLeft: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(renter?.fullName ?? '—',
                    style: AppTextStyles.h2.copyWith(color: c.textMain)),
                if (renter != null) ...[
                  const SizedBox(height: 2),
                  Text(Formatters.phone(renter.phone),
                      style: AppTextStyles.body.copyWith(color: c.textSub)),
                ],
                const SizedBox(height: 2),
                Text(
                  '${rental!.basis.label} · ${Formatters.currency(rental!.rent)}',
                  style: AppTextStyles.body.copyWith(color: c.textSub),
                ),
                Text('Since ${Formatters.date(rental!.startDate)}',
                    style: AppTextStyles.body.copyWith(color: c.textSub)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text('Service',
            style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next service due',
                  style: AppTextStyles.body.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.xs),
              Text(serviceDue == null ? '—' : Formatters.date(serviceDue),
                  style: AppTextStyles.h2.copyWith(color: c.textMain)),
              if (daysToService != null) ...[
                const SizedBox(height: 2),
                Text(
                  daysToService < 0
                      ? 'Overdue by ${-daysToService} days'
                      : 'In $daysToService days',
                  style: AppTextStyles.body.copyWith(
                    color: (daysToService <= 7) ? c.warning : c.textSub,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onEnd != null) ...[
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(label: 'End rental', onPressed: onEnd),
        ],
      ],
    );
  }
}

class _CustomersTab extends StatelessWidget {
  const _CustomersTab({
    required this.rentals,
    required this.rangeLabel,
    required this.resolveName,
  });

  final List<Rental> rentals;
  final String Function(Rental) rangeLabel;
  final String Function(Rental) resolveName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (final r in rentals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              accentLeft: true,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resolveName(r),
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain)),
                        const SizedBox(height: 2),
                        Text(
                          '${r.basis.label} · ${Formatters.currency(r.rent)} · ${rangeLabel(r)}',
                          style:
                              AppTextStyles.body.copyWith(color: c.textSub),
                        ),
                      ],
                    ),
                  ),
                  if (r.rentalStatus == 'active')
                    const StatusPill(
                        label: 'Active', variant: PillVariant.success),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RentalsTab extends StatelessWidget {
  const _RentalsTab({
    required this.rentals,
    required this.rangeLabel,
    required this.durationLabel,
    required this.resolveName,
  });

  final List<Rental> rentals;
  final String Function(Rental) rangeLabel;
  final String Function(Rental) durationLabel;
  final String Function(Rental) resolveName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = rentals.fold<int>(0, (s, r) => s + r.totalCollected);
    final earliest = rentals.isEmpty
        ? null
        : rentals
            .map((r) => r.startDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final sinceLabel =
        earliest == null ? '' : DateFormat('MMM yyyy', 'en_IN').format(earliest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total earned on this vehicle',
                  style: AppTextStyles.body.copyWith(color: c.onPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(Formatters.currency(total),
                  style: TextStyle(
                    color: c.onPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Across ${rentals.length} rental${rentals.length == 1 ? '' : 's'}${sinceLabel.isEmpty ? '' : ' · since $sinceLabel'}',
                style: AppTextStyles.body
                    .copyWith(color: c.onPrimary.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final r in rentals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              accentLeft: true,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resolveName(r),
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain)),
                        const SizedBox(height: 2),
                        Text(
                          '${rangeLabel(r)} · ${r.basis.label} · ${durationLabel(r)}',
                          style:
                              AppTextStyles.body.copyWith(color: c.textSub),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.currency(r.totalCollected),
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: r.rentalStatus == 'active' ? c.success : c.textMain,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
