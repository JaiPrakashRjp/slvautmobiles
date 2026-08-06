import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/installment.dart';
import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import 'rent_detail_screen.dart';

/// Daily rent-collection report: every rent reminder due on the chosen date,
/// with the customer, vehicle, amount and paid/pending status.
class RentalDailyReportScreen extends StatefulWidget {
  const RentalDailyReportScreen({super.key});

  @override
  State<RentalDailyReportScreen> createState() =>
      _RentalDailyReportScreenState();
}

class _RentalDailyReportScreenState extends State<RentalDailyReportScreen> {
  DateTime _date = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.wait([
      context.read<RentalAgreementService>().refresh(),
      context.read<RentalVehicleService>().refresh(),
      context.read<RentalCustomerService>().refresh(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rentals = context.watch<RentalAgreementService>();
    final vehicles = context.read<RentalVehicleService>();
    final customers = context.read<RentalCustomerService>();

    // Rows = (rental, installment) for reminders due on the chosen date, across
    // approved, non-cancelled/seized rentals.
    final rows = <(String rentalId, String customer, String vehicle, Installment inst)>[];
    for (final r in rentals.all()) {
      if (!r.isActive ||
          r.rentalStatus == 'cancelled' ||
          r.rentalStatus == 'seized') {
        continue;
      }
      for (final inst in r.installments) {
        if (_sameDay(inst.dueDate, _date)) {
          final cust = customers.byId(r.customerId)?.fullName ?? 'Customer';
          final veh = vehicles.byId(r.vehicleId);
          final vlabel = veh == null
              ? '—'
              : (veh.regNo.isNotEmpty ? veh.regNo : (veh.chassisNo ?? '—'));
          rows.add((r.id, cust, vlabel, inst));
        }
      }
    }
    rows.sort((a, b) => a.$2.compareTo(b.$2));
    final total = rows.fold<int>(0, (s, e) => s + e.$4.amount);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Daily collections'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refresh),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveBody(
                maxFormWidth: 720,
                phone: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(context.screenHPadding,
                          AppSpacing.lg, context.screenHPadding, AppSpacing.sm),
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 14),
                          decoration: BoxDecoration(
                            color: c.bgSurface,
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            border: Border.all(color: c.borderColor),
                          ),
                          child: Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 18, color: c.textSub),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Due on ${Formatters.date(_date)}',
                                style: AppTextStyles.bodyStrong
                                    .copyWith(color: c.textMain)),
                            const Spacer(),
                            Text('${rows.length} · ${Formatters.currency(total)}',
                                style: AppTextStyles.body
                                    .copyWith(color: c.textSub)),
                          ]),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: rows.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 60),
                                  EmptyState(
                                    icon: Icons.event_available_outlined,
                                    title: 'Nothing due',
                                    subtitle: 'No rent collections on this date.',
                                  ),
                                ],
                              )
                            : ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    context.screenHPadding,
                                    0,
                                    context.screenHPadding,
                                    AppSpacing.xl),
                                children: [
                                  for (final row in rows)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AppSpacing.sm),
                                      child: _DueRow(
                                        customer: row.$2,
                                        vehicle: row.$3,
                                        inst: row.$4,
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => RentDetailScreen(
                                                    rentalId: row.$1))),
                                      ),
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

class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.customer,
    required this.vehicle,
    required this.inst,
    required this.onTap,
  });

  final String customer;
  final String vehicle;
  final Installment inst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = inst.isPaid
        ? ('Paid', c.success)
        : inst.isCancelled
            ? ('Deferred', c.textSub)
            : ('Due', c.warning);
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$customer · $vehicle',
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              const SizedBox(height: 2),
              Text(Formatters.currency(inst.amount),
                  style: AppTextStyles.caption.copyWith(color: c.textSub)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
