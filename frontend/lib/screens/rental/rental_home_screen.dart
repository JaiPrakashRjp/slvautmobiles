import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/vehicle.dart';
import '../../services/rental_vehicle_service.dart';
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
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import '../auto_sale/create_vehicle_screen.dart';
import 'rental_customers_screen.dart';

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

/// Vehicle tab — Not rented / Rented, backed by the rental-scoped vehicle pool
/// (module = rental). Same create / documents / approval as the sale vehicles.
class _RentalVehiclesTab extends StatefulWidget {
  const _RentalVehiclesTab();

  @override
  State<_RentalVehiclesTab> createState() => _RentalVehiclesTabState();
}

class _RentalVehiclesTabState extends State<_RentalVehiclesTab> {
  int _tab = 0; // 0 = Not rented, 1 = Rented

  @override
  void initState() {
    super.initState();
    // Auto-refresh on open so newly-added vehicles / approvals show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RentalVehicleService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vehiclesSvc = context.watch<RentalVehicleService>();
    // Not rented = idle (unassigned); Rented = currently out on rent (assigned).
    final list = _tab == 0 ? vehiclesSvc.unassigned() : vehiclesSvc.assigned();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Auto rental system'),
        automaticallyImplyLeading: false,
        actions: [
          GoldCreateButton(
            iconOnly: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateVehicleScreen(service: vehiclesSvc),
              ),
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
                  tabs: const ['Not rented', 'Rented'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vehiclesSvc.refresh,
                  child: (vehiclesSvc.loading && list.isEmpty)
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 60),
                                EmptyState(
                                  icon: Icons.electric_rickshaw,
                                  title: _tab == 0
                                      ? 'No idle vehicles'
                                      : 'No rented vehicles',
                                  subtitle:
                                      'Tap “+” to add a rental vehicle.',
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                  context.screenHPadding,
                                  0,
                                  context.screenHPadding,
                                  AppSpacing.xl),
                              children: [
                                for (final v in list)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.lg),
                                    child: _RentalVehicleCard(vehicle: v),
                                  ),
                              ],
                            ),
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

  Future<void> _edit(BuildContext context) {
    final service = context.read<RentalVehicleService>();
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateVehicleScreen(existing: vehicle, service: service),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final service = context.read<RentalVehicleService>();
    final actorId = auth.currentUser?.id ?? '';
    final canModify = auth.isSuperAdmin || vehicle.createdBy == actorId;
    final canReview = auth.isSuperAdmin && vehicle.isPending;
    final title =
        vehicle.regNo.isNotEmpty ? vehicle.regNo : (vehicle.chassisNo ?? '—');

    return AppCard(
      onTap: () => _edit(context),
      accentLeft: vehicle.isRejected,
      accentColor: vehicle.isRejected ? c.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              Text(title, style: AppTextStyles.h2.copyWith(color: c.textMain)),
              StatusPill.forEntity(vehicle.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${vehicle.model ?? '—'} · ${vehicle.type.label}',
              style: AppTextStyles.body.copyWith(color: c.textSub)),
          if (vehicle.isRejected &&
              (vehicle.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Rejected: ${vehicle.rejectionReason}',
                style: AppTextStyles.caption.copyWith(color: c.danger)),
          ],
          if (canReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final reason = await ConfirmationDialog.show(
                        context,
                        title: 'Reject vehicle',
                        message: 'Give the staff member a reason.',
                        confirmLabel: 'Reject',
                        danger: true,
                        requireReason: true,
                      );
                      if (reason is String && reason.isNotEmpty) {
                        service.reject(vehicle.id, reason, actorId);
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => service.confirm(vehicle.id, actorId),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: c.borderColor),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View / edit',
                compact: true,
                onPressed: () => _edit(context),
              ),
              if (canModify) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButtonSoft(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  danger: true,
                  compact: true,
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Delete vehicle',
                      message:
                          'Remove this vehicle? This cannot be undone.',
                      confirmLabel: 'Delete',
                      danger: true,
                    );
                    if (ok == true) service.delete(vehicle.id);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
