import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/rental_collection.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_pill.dart';

/// Collection history — mockup 13 ("Rental · Weekly").
class RentalCollectionHistoryScreen extends StatelessWidget {
  const RentalCollectionHistoryScreen({super.key, required this.rentalId});

  final String rentalId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalService>();
    final rental = rentals.rentalById(rentalId);
    final now = DateTime(2026, 6, 2);

    if (rental == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rental')),
        body: const Center(child: Text('Rental not found')),
      );
    }

    final customer = rentals.renterById(rental.customerId);
    final vehicle = rentals.vehicleById(rental.vehicleId);
    final cycleWord = switch (rental.basis) {
      RentalBasis.daily => 'Day',
      RentalBasis.weekly => 'Week',
      RentalBasis.monthly => 'Month',
    };

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: Text('Rental · ${rental.basis.label}')),
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
                    Text('Customer',
                        style: AppTextStyles.body.copyWith(color: c.textSub)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(customer?.fullName ?? '—',
                        style: AppTextStyles.h2.copyWith(color: c.textMain)),
                    const SizedBox(height: 2),
                    Text('Vehicle: ${vehicle?.regNo ?? '—'}',
                        style: AppTextStyles.body.copyWith(color: c.textSub)),
                    Text(
                      '${rental.basis.label} · ${Formatters.currency(rental.rent)}',
                      style: AppTextStyles.body.copyWith(color: c.textSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('${rental.basis.label} history',
                  style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < rental.collections.length; i++) ...[
                      _CycleRow(
                        label: '$cycleWord ${rental.collections[i].cycleNumber}',
                        collection: rental.collections[i],
                        now: now,
                      ),
                      if (i != rental.collections.length - 1)
                        Divider(height: 1, color: c.borderColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (rental.isOngoing)
                PrimaryButton(
                  label: 'Record payment',
                  icon: Icons.add,
                  onPressed: () {
                    final due = rental.collections
                        .where((c) => !c.isPaid)
                        .toList()
                      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    if (due.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All cycles are paid.')),
                      );
                      return;
                    }
                    rentals.recordCollection(rental.id, due.first.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '$cycleWord ${due.first.cycleNumber} payment recorded.'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({
    required this.label,
    required this.collection,
    required this.now,
  });

  final String label;
  final RentalCollection collection;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = collection.statusAt(now);
    final isDue =
        status == ScheduleStatus.overdue || status == ScheduleStatus.dueSoon;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.body.copyWith(color: c.textMain)),
          ),
          if (collection.isPaid)
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
