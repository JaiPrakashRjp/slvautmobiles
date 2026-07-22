import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/second_hand_report.dart';
import '../services/customer_service.dart';
import '../services/pdf_service.dart';
import '../services/vehicle_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/tab_bar_navy.dart';
import 'pdf_preview_screen.dart';

/// Second-hand vehicles report — the used vehicles BOUGHT in a chosen month or
/// custom range (vehicle + previous owner + buying price + status + buyer),
/// viewable as a PDF (preview or download).
class SecondHandReportScreen extends StatefulWidget {
  const SecondHandReportScreen({super.key});

  @override
  State<SecondHandReportScreen> createState() => _SecondHandReportScreenState();
}

class _SecondHandReportScreenState extends State<SecondHandReportScreen> {
  int _mode = 0; // 0 = Month, 1 = Custom range
  late DateTime _month; // first day of the selected month
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
      context.read<VehicleService>().refresh(),
      context.read<CustomerService>().refresh(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  DateTime get _rangeStart =>
      _mode == 0 ? DateTime(_month.year, _month.month) : _dateOnly(_from);
  DateTime get _rangeEnd => _mode == 0
      ? DateTime(_month.year, _month.month + 1, 0)
      : _dateOnly(_to);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _label {
    if (_mode == 0) return Formatters.monthYear(_month);
    return '${Formatters.date(_from)} – ${Formatters.date(_to)}';
  }

  /// Build the report from the loaded second-hand vehicles + customers.
  SecondHandReport _build() {
    final vehicles = context.read<VehicleService>();
    final customers = context.read<CustomerService>();
    final start = _rangeStart;
    final end = _rangeEnd;

    bool inRange(DateTime? d) {
      if (d == null) return false;
      final x = _dateOnly(d);
      return !x.isBefore(start) && !x.isAfter(end);
    }

    final rows = <SecondHandRow>[];
    for (final v in vehicles.all()) {
      if (v.type != VehicleType.secondHand) continue;
      if (v.isRejected) continue;
      if (!inRange(v.purchaseDate)) continue; // bought in the period
      final sold = v.saleStatus == SaleStatus.sold;
      final buyer = v.assignedToCustomerId == null
          ? null
          : customers.byId(v.assignedToCustomerId!);
      rows.add(SecondHandRow(
        purchaseDate: v.purchaseDate,
        vehicle: v.regNo.isNotEmpty ? v.regNo : (v.chassisNo ?? '—'),
        model: v.model ?? '—',
        fuel: v.fuelType?.label ?? '—',
        prevOwnerName: (v.prevOwnerName?.isNotEmpty ?? false)
            ? v.prevOwnerName!
            : '—',
        prevOwnerMobile: v.prevOwnerMobile ?? '',
        buyingPrice: (v.buyingExpenses ?? 0).round(),
        sold: sold,
        buyerName: buyer?.fullName,
        buyerMobile: buyer?.phone,
      ));
    }
    rows.sort((a, b) => (a.purchaseDate ?? DateTime(2000))
        .compareTo(b.purchaseDate ?? DateTime(2000)));

    return SecondHandReport(
      from: start,
      to: end,
      label: _label,
      rows: rows,
    );
  }

  void _stepMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _to = d);
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
        title: const Text('Second-hand vehicles'),
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
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Preview PDF',
                            icon: Icons.picture_as_pdf_outlined,
                            onPressed: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PdfPreviewScreen(
                                title: 'Second-hand vehicles',
                                fileName:
                                    'second-hand-${report.label.replaceAll(' ', '-')}.pdf',
                                builder: () => context
                                    .read<PdfService>()
                                    .secondHandReportBytes(report),
                              ),
                            )),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Download PDF',
                            icon: Icons.download_outlined,
                            onPressed: () => context
                                .read<PdfService>()
                                .shareSecondHandReport(report),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _monthPicker(AppColors c, bool isThisMonth) {
    return Row(
      children: [
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _stepMonth(-1)),
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
            onPressed: isThisMonth ? null : () => _stepMonth(1)),
      ],
    );
  }

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
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textMain)),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        field('From', _from, _pickFrom),
        const SizedBox(width: AppSpacing.md),
        field('To', _to, _pickTo),
      ],
    );
  }

  Widget _overview(AppColors c, SecondHandReport r) {
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
          Text('Bought · ${r.label}',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            stat('${r.count}', 'Vehicles bought'),
            stat('${r.soldCount}', 'Sold', color: c.success),
            stat('${r.inStockCount}', 'In stock'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            stat(Formatters.currency(r.totalBuying), 'Total buying price'),
            const Spacer(),
          ]),
        ],
      ),
    );
  }
}
