import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle.dart';
import '../../services/rental_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/tab_bar_navy.dart';
import 'assign_rental_screen.dart';
import 'rental_customers_screen.dart';
import 'rental_vehicle_detail_screen.dart';

/// Auto Rental module shell — Vehicle / Customer tabs (mockups 11 & 14).
class RentalHomeScreen extends StatefulWidget {
  const RentalHomeScreen({super.key});

  @override
  State<RentalHomeScreen> createState() => _RentalHomeScreenState();
}

class _RentalHomeScreenState extends State<RentalHomeScreen> {
  int _index = 0;

  static const _items = [
    BottomNavItem(icon: Icons.electric_rickshaw, label: 'Vehicle'),
    BottomNavItem(icon: Icons.people_outline, label: 'Customer'),
  ];

  final _pages = const [_RentalVehiclesTab(), RentalCustomersScreen()];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = IndexedStack(index: _index, children: _pages);

    if (context.isTablet) {
      return Scaffold(
        backgroundColor: c.bgCanvas,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: c.primary,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: IconThemeData(color: c.accent),
                unselectedIconTheme: IconThemeData(color: c.onPrimary),
                selectedLabelTextStyle: TextStyle(color: c.accent),
                unselectedLabelTextStyle: TextStyle(color: c.onPrimary),
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(
                      icon: Icon(it.icon),
                      label: Text(it.label),
                    ),
                ],
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: body,
      bottomNavigationBar: BottomNavBar(
        items: _items,
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Vehicle tab — Rented / Not Rented (mockup 11).
class _RentalVehiclesTab extends StatefulWidget {
  const _RentalVehiclesTab();

  @override
  State<_RentalVehiclesTab> createState() => _RentalVehiclesTabState();
}

class _RentalVehiclesTabState extends State<_RentalVehiclesTab> {
  int _tab = 0; // 0 = Rented, 1 = Not Rented

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalService>();
    final vehicles =
        _tab == 0 ? rentals.rentedVehicles() : rentals.notRentedVehicles();
    final serviceDue = rentals.serviceDueWithin(7);

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
              if (serviceDue.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(context.screenHPadding,
                      AppSpacing.lg, context.screenHPadding, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: c.warningTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.build_outlined, size: 18, color: c.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${serviceDue.length} vehicle${serviceDue.length == 1 ? '' : 's'} due for service within 7 days',
                            style: AppTextStyles.label.copyWith(color: c.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.lg, context.screenHPadding, AppSpacing.md),
                child: TabBarNavy(
                  tabs: const ['Rented', 'Not rented'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: vehicles.isEmpty
                    ? EmptyState(
                        title: _tab == 0
                            ? 'No rented vehicles'
                            : 'No idle vehicles',
                        subtitle: 'Tap “+” to assign a vehicle on rent.',
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                            context.screenHPadding, AppSpacing.xl),
                        children: [
                          for (final v in vehicles)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _RentalVehicleCard(vehicle: v),
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

class _RentalVehicleCard extends StatelessWidget {
  const _RentalVehicleCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.read<RentalService>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vehicle.regNo,
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
          const SizedBox(height: AppSpacing.xs),
          Text('Bajaj RE · Three-wheeler',
              style: AppTextStyles.body.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RentalVehicleDetailScreen(vehicleId: vehicle.id),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButtonSoft(
                icon: Icons.delete_outline,
                tooltip: 'End rental',
                danger: true,
                onPressed: () async {
                  final active = rentals.activeRentalForVehicle(vehicle.id);
                  if (active == null) return;
                  final ok = await ConfirmationDialog.show(
                    context,
                    title: 'End rental',
                    message: 'End the rental on ${vehicle.regNo}?',
                    confirmLabel: 'End rental',
                    danger: true,
                  );
                  if (ok == true) rentals.endRental(active.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
