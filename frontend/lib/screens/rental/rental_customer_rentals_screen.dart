import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/status_pill.dart';
import '../auto_sale/create_customer_screen.dart';
import 'assign_rent_screen.dart';
import 'rent_detail_screen.dart';

/// Rental customer detail (customer perspective): their details + every rental
/// they hold, with a "Rent a vehicle" action (a customer can rent multiple).
class RentalCustomerRentalsScreen extends StatefulWidget {
  const RentalCustomerRentalsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<RentalCustomerRentalsScreen> createState() =>
      _RentalCustomerRentalsScreenState();
}

class _RentalCustomerRentalsScreenState
    extends State<RentalCustomerRentalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() => Future.wait([
        context.read<RentalCustomerService>().refresh(),
        context.read<RentalAgreementService>().refresh(),
        context.read<RentalVehicleService>().refresh(),
      ]);

  Future<void> _rentAVehicle() async {
    final vehicles = context.read<RentalVehicleService>();
    final navigator = Navigator.of(context);
    // Available rental vehicles = active + not currently assigned.
    final available = vehicles
        .all()
        .where((v) => v.isActive && !v.isAssigned)
        .toList();
    final vehicleId = await OptionSheet.show<String>(
      context,
      title: 'Rent which vehicle',
      searchable: true,
      searchHint: 'Search by reg / chassis',
      options: available
          .map((v) => SheetOption(
                value: v.id,
                label: v.regNo.isNotEmpty ? v.regNo : (v.chassisNo ?? '—'),
                subtitle: v.model ?? '',
              ))
          .toList(),
    );
    if (vehicleId == null) return;
    await navigator.push(MaterialPageRoute(
      builder: (_) =>
          AssignRentScreen(customerId: widget.customerId, vehicleId: vehicleId),
    ));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customer =
        context.watch<RentalCustomerService>().byId(widget.customerId);
    final rentals = context
        .watch<RentalAgreementService>()
        .forCustomer(widget.customerId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final vehicles = context.read<RentalVehicleService>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Customer detail'),
        actions: [
          if (customer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit customer',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CreateCustomerScreen(
                  existing: customer,
                  service: context.read<RentalCustomerService>(),
                ),
              )),
            ),
        ],
      ),
      body: SafeArea(
        child: customer == null
            ? const Center(child: Text('Customer not found'))
            : ResponsiveBody(
                maxFormWidth: 640,
                phone: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(context.screenHPadding),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.sm,
                              children: [
                                Text(customer.fullName,
                                    style: AppTextStyles.h2
                                        .copyWith(color: c.textMain)),
                                StatusPill.forEntity(customer.status),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            CallChip(phone: customer.phone),
                            if (customer.address.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(customer.address,
                                  style: AppTextStyles.body
                                      .copyWith(color: c.textSub)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Rent a vehicle',
                        icon: Icons.vpn_key_outlined,
                        onPressed: _rentAVehicle,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Rentals',
                          style: AppTextStyles.pageTitle
                              .copyWith(color: c.textMain)),
                      const SizedBox(height: AppSpacing.sm),
                      if (rentals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: EmptyState(
                            icon: Icons.electric_rickshaw,
                            title: 'No rentals yet',
                            subtitle: 'Tap "Rent a vehicle" to start one.',
                          ),
                        )
                      else
                        for (final r in rentals) ...[
                          _RentalRow(
                            invoiceNo: r.invoiceNo ?? 'Rental #${r.id}',
                            vehicle: () {
                              final v = vehicles.byId(r.vehicleId);
                              return v == null
                                  ? '—'
                                  : (v.regNo.isNotEmpty
                                      ? v.regNo
                                      : (v.chassisNo ?? '—'));
                            }(),
                            total: r.totalAmount,
                            remaining: r.remainingAmount,
                            statusLabel: r.isCompleted
                                ? 'Completed'
                                : r.rentalStatus == 'seized'
                                    ? 'Seized'
                                    : r.rentalStatus,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        RentDetailScreen(rentalId: r.id))),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _RentalRow extends StatelessWidget {
  const _RentalRow({
    required this.invoiceNo,
    required this.vehicle,
    required this.total,
    required this.remaining,
    required this.statusLabel,
    required this.onTap,
  });

  final String invoiceNo;
  final String vehicle;
  final int total;
  final int remaining;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$invoiceNo · $vehicle',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
                const SizedBox(height: 2),
                Text(
                  'Total ${Formatters.currency(total)} · ${remaining > 0 ? '${Formatters.currency(remaining)} due' : 'Paid'}',
                  style: AppTextStyles.caption.copyWith(
                      color: remaining > 0 ? c.danger : c.success),
                ),
              ],
            ),
          ),
          Text(statusLabel,
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
          Icon(Icons.chevron_right, color: c.textSub),
        ],
      ),
    );
  }
}
