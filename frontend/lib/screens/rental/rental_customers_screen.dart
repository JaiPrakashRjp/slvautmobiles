import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'assign_rental_screen.dart';
import 'rental_customer_detail_screen.dart';

/// Rental customers — mockup 14. Active / Inactive renters.
class RentalCustomersScreen extends StatefulWidget {
  const RentalCustomersScreen({super.key});

  @override
  State<RentalCustomersScreen> createState() => _RentalCustomersScreenState();
}

class _RentalCustomersScreenState extends State<RentalCustomersScreen> {
  int _tab = 0; // 0 = Active, 1 = Inactive

  static final DateTime _today = DateTime(2026, 6, 2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalService>();

    final active = rentals.activeRentals();
    final activeCustomerIds = active.map((r) => r.customerId).toSet();
    final items = _tab == 0
        ? rentals.verifiedRenters().where((r) => activeCustomerIds.contains(r.id))
        : rentals
            .verifiedRenters()
            .where((r) => !activeCustomerIds.contains(r.id));
    final list = items.toList();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Auto rental system'),
        automaticallyImplyLeading: false,
        actions: [
          GoldCreateButton(
            iconOnly: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AssignRentalScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.lg, context.screenHPadding, AppSpacing.md),
                child: TabBarNavy(
                  tabs: const ['Active', 'Inactive'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: _tab == 0
                            ? 'No active renters'
                            : 'No inactive renters',
                        subtitle: 'Assign a vehicle to start a rental.',
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                            context.screenHPadding, AppSpacing.xl),
                        children: [
                          for (final cust in list)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _RentalCustomerCard(
                                customer: cust,
                                rental: rentals.activeRentalForCustomer(cust.id),
                                now: _today,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RentalCustomerCard extends StatelessWidget {
  const _RentalCustomerCard({
    required this.customer,
    required this.rental,
    required this.now,
  });

  final Customer customer;
  final Rental? rental;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.read<RentalService>();
    final vehicle =
        rental == null ? null : rentals.vehicleById(rental!.vehicleId);
    final unit = rental == null
        ? ''
        : switch (rental!.basis) {
            RentalBasis.daily => '/day',
            RentalBasis.weekly => '/wk',
            RentalBasis.monthly => '/mo',
          };
    final dueLabel = rental?.dueLabel(now) ?? 'Inactive';
    final onTime = dueLabel == 'On time';

    return AppCard(
      accentLeft: rental != null,
      onTap: rental == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RentalCustomerDetailScreen(customerId: customer.id),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(customer.fullName,
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
          const SizedBox(height: 2),
          if (rental != null)
            Text('${vehicle?.regNo ?? ''} · ${rental!.basis.label}',
                style: AppTextStyles.body.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (rental != null)
                Expanded(
                  child: Text(
                    '${Formatters.currency(rental!.rent)}$unit',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.textMain),
                  ),
                )
              else
                const Spacer(),
              if (rental != null)
                StatusPill(
                  label: dueLabel,
                  variant: onTime ? PillVariant.success : PillVariant.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RentalCustomerDetailScreen(customerId: customer.id),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (rental != null)
                IconButtonSoft(
                  icon: Icons.delete_outline,
                  tooltip: 'End rental',
                  danger: true,
                  onPressed: () => rentals.endRental(rental!.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

