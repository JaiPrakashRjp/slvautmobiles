import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rental_report.dart';
import '../../services/api_rental_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/tab_bar_navy.dart';

/// Rental business report over a month / custom range — rentals started, total
/// rent, collected, outstanding + idle vehicles. Reuses the sale [MonthlyReport]
/// shape + PDF (rent maps to price, collected to received, remaining to balance).
class RentalMonthlyReportScreen extends StatefulWidget {
  const RentalMonthlyReportScreen({super.key});

  @override
  State<RentalMonthlyReportScreen> createState() =>
      _RentalMonthlyReportScreenState();
}

class _RentalMonthlyReportScreenState extends State<RentalMonthlyReportScreen> {
  int _mode = 0;
  late DateTime _month;
  late DateTime _from;
  late DateTime _to;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
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

  DateTime get _rangeStart =>
      _mode == 0 ? DateTime(_month.year, _month.month) : _dateOnly(_from);
  DateTime get _rangeEnd => _mode == 0
      ? DateTime(_month.year, _month.month + 1, 0)
      : _dateOnly(_to);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _label => _mode == 0
      ? Formatters.monthYear(_month)
      : '${Formatters.date(_from)} – ${Formatters.date(_to)}';

  RentalReport _build() {
    final rentals = context.read<RentalAgreementService>();
    final vehicles = context.read<RentalVehicleService>();
    final customers = context.read<RentalCustomerService>();
    final start = _rangeStart;
    final end = _rangeEnd;

    bool inRange(DateTime? d) {
      if (d == null) return false;
      final x = _dateOnly(d);
      return !x.isBefore(start) && !x.isAfter(end);
    }

    final rentalRows = <RentalReportRow>[];
    final collections = <RentalCollectionRow>[];

    for (final r in rentals.all()) {
      if (!r.isActive || r.rentalStatus == 'cancelled') continue;
      final cust = customers.byId(r.customerId);
      final veh = vehicles.byId(r.vehicleId);
      final vlabel = veh?.regNo.isNotEmpty == true
          ? veh!.regNo
          : (veh?.chassisNo ?? '—');
      final custName = cust?.fullName ?? 'Customer';

      // Rent collected IN the period (approved payments whose paid-date is in
      // range), across every rental — the real monthly income.
      var collectedInPeriod = 0;
      for (final p in r.payments) {
        if (p.isApproved && inRange(p.paidAt)) {
          collectedInPeriod += p.amount;
          collections.add(RentalCollectionRow(
            date: p.paidAt ?? r.createdAt,
            customerName: custName,
            vehicle: vlabel,
            amount: p.amount,
          ));
        }
      }

      // Rentals STARTED in the period → the rentals table.
      final when = r.startDate ?? r.createdAt;
      if (inRange(when)) {
        rentalRows.add(RentalReportRow(
          date: when,
          customerName: custName,
          vehicle: vlabel,
          type: r.rentalType ?? '',
          rent: r.periodAmount,
          collected: collectedInPeriod,
        ));
      }
    }
    rentalRows.sort((a, b) => a.date.compareTo(b.date));
    collections.sort((a, b) => a.date.compareTo(b.date));

    final idle = vehicles
        .all()
        .where((v) => v.isActive && !v.isAssigned)
        .map((v) => MonthlyVehicleRow(
              identifier: v.regNo.isNotEmpty ? v.regNo : (v.chassisNo ?? '—'),
              model: v.model ?? '—',
              type: v.type.label,
              purchaseDate: v.purchaseDate,
            ))
        .toList();

    final newCustomers =
        customers.all().where((c) => inRange(c.createdAt)).length;

    return RentalReport(
      from: start,
      to: end,
      label: _label,
      rentals: rentalRows,
      collections: collections,
      idle: idle,
      newCustomerCount: newCustomers,
    );
  }

  void _step(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final report = _loading ? null : _build();
    final isThisMonth =
        _mode == 0 && DateUtils.isSameMonth(_month, DateTime.now());

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Rental report'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refresh),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    TabBarNavy(
                      tabs: const ['Month', 'Custom range'],
                      index: _mode,
                      onChanged: (i) => setState(() => _mode = i),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_mode == 0)
                      _monthPicker(c, isThisMonth)
                    else
                      _rangePicker(c),
                    const SizedBox(height: AppSpacing.lg),
                    _overview(c, report!),
                    const SizedBox(height: AppSpacing.lg),
                    Row(children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Preview PDF',
                          icon: Icons.picture_as_pdf_outlined,
                          onPressed: () => context
                              .read<PdfService>()
                              .previewRentalReport(report),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Download PDF',
                          icon: Icons.download_outlined,
                          onPressed: () => context
                              .read<PdfService>()
                              .shareRentalReport(report),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _monthPicker(AppColors c, bool isThisMonth) => Row(children: [
        IconButton(
            icon: const Icon(Icons.chevron_left), onPressed: () => _step(-1)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: c.borderColor),
            ),
            alignment: Alignment.center,
            child: Text(Formatters.monthYear(_month),
                style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isThisMonth ? null : () => _step(1)),
      ]);

  Widget _rangePicker(AppColors c) {
    Widget field(String label, DateTime value, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: c.bgSurface,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: c.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.caption.copyWith(color: c.textSub)),
                  const SizedBox(height: 2),
                  Text(Formatters.date(value),
                      style:
                          AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
                ],
              ),
            ),
          ),
        );
    return Row(children: [
      field('From', _from, () => _pick(true)),
      const SizedBox(width: AppSpacing.md),
      field('To', _to, () => _pick(false)),
    ]);
  }

  Widget _overview(AppColors c, RentalReport r) {
    Widget stat(String value, String label, {Color? color}) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: c.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTextStyles.bodyStrong
                        .copyWith(color: color ?? c.textMain)),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTextStyles.caption.copyWith(color: c.textSub)),
              ],
            ),
          ),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview · ${r.label}',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            stat('${r.rentalCount}', 'Rentals'),
            stat('${r.weeklyCount}', 'Weekly'),
            stat('${r.dailyCount}', 'Daily'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            stat(Formatters.currency(r.collectedTotal), 'Rent collected',
                color: c.success),
            stat('${r.idle.length}', 'Idle vehicles'),
            stat('${r.newCustomerCount}', 'New customers'),
          ]),
        ],
      ),
    );
  }
}
