import 'package:flutter/material.dart';

import '../models/daily_reminder.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/call_chip.dart';
import '../widgets/empty_state.dart';
import 'auto_sale/sale_detail_screen.dart';

/// Daily reminder / collection report — every installment due on the chosen day,
/// with the customer, amount and current status. Any signed-in staff can view.
class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _api = ApiClient();
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _error = false;
  List<DailyReminder> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data =
          await _api.get('/reports/daily-reminders', query: {'on': _apiDate(_date)});
      if (!mounted) return;
      setState(() {
        _rows = (data as List)
            .map((j) => DailyReminder.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  void _step(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    final total = _rows.fold<int>(0, (s, r) => s + r.amount);
    final collected =
        _rows.where((r) => r.isPaid).fold<int>(0, (s, r) => s + r.amount);
    final paidCount = _rows.where((r) => r.isPaid).length;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Daily report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 680,
          phone: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Date selector ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.md, context.screenHPadding, AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _step(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.bgSurface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                            border: Border.all(color: c.borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 18, color: c.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                isToday
                                    ? 'Today · ${Formatters.date(_date)}'
                                    : Formatters.date(_date),
                                style: AppTextStyles.bodyStrong
                                    .copyWith(color: c.textMain),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isToday ? null : () => _step(1),
                    ),
                  ],
                ),
              ),

              // ── Summary ────────────────────────────────────────────────
              if (!_loading && !_error && _rows.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.screenHPadding),
                  child: Row(
                    children: [
                      _Stat(
                          label: 'Reminders',
                          value: '${_rows.length}',
                          c: c),
                      _Stat(
                          label: 'Total due',
                          value: Formatters.currency(total),
                          c: c),
                      _Stat(
                          label: 'Collected',
                          value:
                              '$paidCount · ${Formatters.currency(collected)}',
                          color: c.success,
                          c: c),
                    ],
                  ),
                ),

              // ── List ───────────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error
                          ? ListView(children: const [
                              SizedBox(height: 120),
                              EmptyState(
                                icon: Icons.error_outline,
                                title: 'Could not load the report',
                                subtitle: 'Pull down to try again.',
                              ),
                            ])
                          : _rows.isEmpty
                              ? ListView(children: [
                                  const SizedBox(height: 120),
                                  EmptyState(
                                    icon: Icons.event_available_outlined,
                                    title: 'No reminders',
                                    subtitle:
                                        'Nothing was due on ${Formatters.date(_date)}.',
                                  ),
                                ])
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                      context.screenHPadding,
                                      AppSpacing.md,
                                      context.screenHPadding,
                                      AppSpacing.xl),
                                  itemCount: _rows.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (_, i) =>
                                      _ReminderRow(row: _rows[i]),
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

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label, required this.value, required this.c, this.color});
  final String label;
  final String value;
  final AppColors c;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.row});
  final DailyReminder row;

  (String, Color) _status(AppColors c) {
    if (row.isPaid) return ('Paid', c.success);
    if (row.isTaken) {
      return ('Taken${row.takenByName != null ? ' · ${row.takenByName}' : ''}',
          c.primary);
    }
    if (row.isCancelled) return ('Deferred', c.textSub);
    return ('Pending', c.warning);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (statusLabel, statusColor) = _status(c);
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SaleDetailScreen(saleId: '${row.saleId}'),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.customerName,
                    style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              ),
              Text(Formatters.currency(row.amount),
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
            ],
          ),
          const SizedBox(height: 2),
          Text(row.vehicleReg == null || row.vehicleReg!.isEmpty
              ? 'Vehicle —'
              : row.vehicleReg!,
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              CallChip(phone: row.customerPhone),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: AppTextStyles.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
