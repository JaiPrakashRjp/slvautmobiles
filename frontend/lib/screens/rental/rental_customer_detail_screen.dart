import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';
import 'rental_collection_history_screen.dart';
import 'rental_vehicle_detail_screen.dart';

/// Rental customer detail — mockup 15.
class RentalCustomerDetailScreen extends StatelessWidget {
  const RentalCustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalService>();
    final customer = rentals.renterById(customerId);
    final rental = rentals.activeRentalForCustomer(customerId);
    final vehicle =
        rental == null ? null : rentals.vehicleById(rental.vehicleId);
    final now = DateTime(2026, 6, 2);
    final cycleWord = rental == null
        ? 'Cycle'
        : switch (rental.basis) {
            RentalBasis.daily => 'Day',
            RentalBasis.weekly => 'Week',
            RentalBasis.monthly => 'Month',
          };

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Customer detail'),
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
          maxFormWidth: 560,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer?.fullName ?? '—',
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                    if (customer != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(Formatters.phone(customer.phone),
                          style: AppTextStyles.body.copyWith(color: c.textSub)),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: c.success),
                        const SizedBox(width: 4),
                        Text('Verified',
                            style:
                                AppTextStyles.label.copyWith(color: c.success)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (rental == null)
                Text('No active rental',
                    style: AppTextStyles.body.copyWith(color: c.textSub))
              else ...[
                Text('Assigned vehicle',
                    style:
                        AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  accentLeft: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RentalVehicleDetailScreen(vehicleId: rental.vehicleId),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle?.regNo ?? '—',
                          style: AppTextStyles.h2.copyWith(color: c.textMain)),
                      const SizedBox(height: 2),
                      Text('Bajaj RE · Three-wheeler',
                          style: AppTextStyles.body.copyWith(color: c.textSub)),
                      const SizedBox(height: 2),
                      Text(
                        '${rental.basis.label} · ${Formatters.currency(rental.rent)} · Since ${Formatters.date(rental.startDate)}',
                        style: AppTextStyles.body.copyWith(color: c.textSub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${rental.basis.label} history',
                        style: AppTextStyles.pageTitle
                            .copyWith(color: c.textMain)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RentalCollectionHistoryScreen(
                              rentalId: rental.id),
                        ),
                      ),
                      child: const Text('Record'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0;
                          i < rental.collections.length;
                          i++) ...[
                        _MiniCycleRow(
                          label:
                              '$cycleWord ${rental.collections[i].cycleNumber}',
                          paid: rental.collections[i].isPaid,
                          status: rental.collections[i].statusAt(now),
                        ),
                        if (i != rental.collections.length - 1)
                          Divider(height: 1, color: c.borderColor),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCycleRow extends StatelessWidget {
  const _MiniCycleRow({
    required this.label,
    required this.paid,
    required this.status,
  });

  final String label;
  final bool paid;
  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDue =
        status == ScheduleStatus.overdue || status == ScheduleStatus.dueSoon;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: AppTextStyles.body.copyWith(color: c.textMain)),
          ),
          if (paid)
            Icon(Icons.check, color: c.success, size: 20)
          else if (isDue)
            const StatusPill(label: 'Due', variant: PillVariant.warning)
          else
            Text('Upcoming',
                style: AppTextStyles.body.copyWith(color: c.textSub)),
        ],
      ),
    );
  }
}
