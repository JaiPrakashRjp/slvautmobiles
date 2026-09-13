import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/emi.dart';
import '../../models/loan_report.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/empty_state.dart';
import 'loan_detail_screen.dart';

/// Daily EMI-collection report: every EMI due on the chosen date, with the
/// customer, vehicle, amount and paid/partial/pending status. Mirrors the
/// rental daily-collections report.
class LoanDailyReportScreen extends StatefulWidget {
  const LoanDailyReportScreen({super.key});

  @override
  State<LoanDailyReportScreen> createState() => _LoanDailyReportScreenState();
}

class _LoanDailyReportScreenState extends State<LoanDailyReportScreen> {
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
      context.read<LoanService>().refresh(),
      context.read<LoanVehicleService>().refresh(),
      context.read<LoanCustomerService>().refresh(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

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
    final loans = context.watch<LoanService>();
    final vehicles = context.read<LoanVehicleService>();
    final customers = context.read<LoanCustomerService>();

    // Rows = (loan, emi) for EMIs due on the chosen date, across approved,
    // non-seized loans (filter shared with the monthly report + tests).
    final rows = <(String loanId, String customer, String phone, String vehicle, Emi emi)>[];
    for (final (l, emi) in LoanReport.emisDueOn(loans.all(), _date)) {
      final custObj = customers.byId(l.customerId);
      rows.add((
        l.id,
        custObj?.fullName ?? 'Customer',
        custObj?.phone ?? '',
        vehicles.byId(l.vehicleId ?? '')?.displayLabel ?? '—',
        emi,
      ));
    }
    rows.sort((a, b) => a.$2.compareTo(b.$2));
    final total = rows.fold<int>(0, (s, e) => s + e.$5.totalDue);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Daily EMI collections'),
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
                                    subtitle:
                                        'No EMI collections on this date.',
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
                                        phone: row.$3,
                                        vehicle: row.$4,
                                        emi: row.$5,
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) => LoanDetailScreen(
                                                    loanId: row.$1))),
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
    required this.phone,
    required this.vehicle,
    required this.emi,
    required this.onTap,
  });

  final String customer;
  final String phone;
  final String vehicle;
  final Emi emi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = emi.isPaid
        ? ('Paid', c.success)
        : emi.isPartial
            ? ('Partial', c.warning)
            : ('Pending', c.warning);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$customer · $vehicle',
                      style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
                  const SizedBox(height: 2),
                  Text('EMI ${emi.sequenceNumber} · ${Formatters.currency(emi.totalDue)}',
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
          if (phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            CallChip(phone: phone),
          ],
        ],
      ),
    );
  }
}
