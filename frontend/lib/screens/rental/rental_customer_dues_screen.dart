import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/installment.dart';
import '../../models/rental_agreement.dart';
import '../../models/rental_customer_statement.dart';
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
import '../../widgets/empty_state.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import 'rent_detail_screen.dart';

/// Per-customer dues: pick a rental customer from a searchable dropdown, then see
/// their full standing across every rental — total pending, total collected, how
/// many reminders are open / overdue / awaiting approval — with a per-rental,
/// per-reminder breakdown. Tapping a rental opens the full rent detail to act.
class RentalCustomerDuesScreen extends StatefulWidget {
  const RentalCustomerDuesScreen({super.key});

  @override
  State<RentalCustomerDuesScreen> createState() =>
      _RentalCustomerDuesScreenState();
}

class _RentalCustomerDuesScreenState extends State<RentalCustomerDuesScreen> {
  String? _customerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<RentalAgreementService>().refresh(),
      context.read<RentalCustomerService>().refresh(),
      context.read<RentalVehicleService>().refresh(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _pickCustomer() async {
    final customers = context.read<RentalCustomerService>();
    final listable =
        customers.all().where((c) => c.isActive || c.isPending).toList()
          ..sort((a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select customer',
      searchable: true,
      searchHint: 'Search by name or phone',
      selected: _customerId,
      options: listable
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle:
                    c.isActive ? c.phone : '${c.phone}  ·  Pending approval',
              ))
          .toList(),
    );
    if (picked != null) setState(() => _customerId = picked);
  }

  // ── Money helpers (mirror the rent-detail computation) ─────────────────────
  /// Approved payments recorded against one reminder (partial payments add up).
  int _paidFor(RentalAgreement r, Installment inst) => r.payments
      .where((p) => p.installmentId == inst.id && p.isApproved)
      .fold(0, (s, p) => s + p.amount);

  int _remainingFor(RentalAgreement r, Installment inst) =>
      (inst.amount - _paidFor(r, inst)).clamp(0, inst.amount);

  bool _isOverdue(Installment inst) {
    if (inst.isPaid || inst.isCancelled) return false;
    final now = DateTime.now();
    final due = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// A reminder still owing money (not fully paid, not cancelled).
  bool _isOpen(Installment inst) => !inst.isPaid && !inst.isCancelled;

  /// Rent collected on a rental — sum of approved payments (excludes advance).
  int _collected(RentalAgreement r) =>
      r.payments.where((p) => p.isApproved).fold(0, (s, p) => s + p.amount);

  /// Outstanding on a rental — remaining across every open reminder.
  int _pending(RentalAgreement r) => r.installments
      .where(_isOpen)
      .fold(0, (s, i) => s + _remainingFor(r, i));

  /// Assemble the printable statement from the same figures shown on screen.
  RentalCustomerStatement _buildStatement(
      String name, String phone, List<RentalAgreement> rentals) {
    final vehicles = context.read<RentalVehicleService>();
    var pending = 0, collected = 0, open = 0, overdue = 0, awaiting = 0, active = 0;
    final rows = <RentalStatementRow>[];
    for (final r in rentals) {
      pending += _pending(r);
      collected += _collected(r);
      if (r.rentalStatus == 'active') active++;
      final reminders = <StatementReminderRow>[];
      for (final i in r.installments) {
        if (_isOpen(i)) open++;
        if (_isOverdue(i)) overdue++;
        if (r.pendingPaymentFor(i.id) != null) awaiting++;
      }
      final openInst = r.installments.where(_isOpen).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      for (final i in openInst) {
        reminders.add(StatementReminderRow(
          dueDate: i.dueDate,
          remaining: _remainingFor(r, i),
          paid: _paidFor(r, i),
          overdue: _isOverdue(i),
        ));
      }
      final veh = vehicles.byId(r.vehicleId);
      final vlabel = veh == null
          ? 'Vehicle'
          : (veh.regNo.isNotEmpty ? veh.regNo : (veh.chassisNo ?? 'Vehicle'));
      rows.add(RentalStatementRow(
        vehicle: vlabel,
        invoice: r.invoiceNo ?? 'Rental #${r.id}',
        status: _statusLabel(r),
        rentLabel: r.isRecurring
            ? '${Formatters.currency(r.periodAmount)} / '
                '${r.rentalType == 'daily' ? 'day' : 'week'}'
            : '',
        collected: _collected(r),
        pending: _pending(r),
        reminders: reminders,
      ));
    }
    return RentalCustomerStatement(
      customerName: name,
      customerPhone: phone,
      totalPending: pending,
      totalCollected: collected,
      activeRentals: active,
      openReminders: open,
      overdue: overdue,
      awaitingApproval: awaiting,
      rentals: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Watch so approvals / payments made elsewhere reflect here live.
    final rentalsSvc = context.watch<RentalAgreementService>();
    final customer =
        _customerId == null ? null : context.read<RentalCustomerService>().byId(_customerId!);

    // All of this customer's rentals, excluding cancelled ones, newest first.
    final rentals = _customerId == null
        ? <RentalAgreement>[]
        : (rentalsSvc.forCustomer(_customerId!)
            .where((r) => r.rentalStatus != 'cancelled')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Customer dues'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _refresh),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.screenHPadding),
              children: [
                _picker(c, customer?.fullName, customer?.phone),
                const SizedBox(height: AppSpacing.lg),
                if (_customerId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Pick a customer',
                      subtitle:
                          'Select a customer to see how much is pending, how '
                          'much is paid, and their open reminders.',
                    ),
                  )
                else if (rentals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No rentals',
                      subtitle: 'This customer has no active rental records.',
                    ),
                  )
                else ...[
                  _summaryCard(c, rentals),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Rentals',
                      style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final r in rentals) ...[
                    _rentalCard(c, r),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Preview PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: () => context
                            .read<PdfService>()
                            .previewCustomerStatement(_buildStatement(
                                customer?.fullName ?? 'Customer',
                                customer?.phone ?? '',
                                rentals)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Download PDF',
                        icon: Icons.download_outlined,
                        onPressed: () => context
                            .read<PdfService>()
                            .shareCustomerStatement(_buildStatement(
                                customer?.fullName ?? 'Customer',
                                customer?.phone ?? '',
                                rentals)),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picker(AppColors c, String? name, String? phone) {
    return InkWell(
      onTap: _pickCustomer,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: c.borderColor),
        ),
        child: Row(children: [
          Icon(Icons.person_search_outlined, color: c.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: name == null
                ? Text('Select customer',
                    style: AppTextStyles.body.copyWith(color: c.textSub))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: c.textMain)),
                      if (phone != null && phone.isNotEmpty)
                        Text(phone,
                            style: AppTextStyles.caption
                                .copyWith(color: c.textSub)),
                    ],
                  ),
          ),
          Icon(Icons.unfold_more, color: c.textSub),
        ]),
      ),
    );
  }

  Widget _summaryCard(AppColors c, List<RentalAgreement> rentals) {
    var pending = 0, collected = 0, openReminders = 0, overdue = 0, awaiting = 0;
    var activeRentals = 0;
    for (final r in rentals) {
      pending += _pending(r);
      collected += _collected(r);
      if (r.rentalStatus == 'active') activeRentals++;
      for (final i in r.installments) {
        if (_isOpen(i)) openReminders++;
        if (_isOverdue(i)) overdue++;
        if (r.pendingPaymentFor(i.id) != null) awaiting++;
      }
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total pending',
                        style:
                            AppTextStyles.caption.copyWith(color: c.textSub)),
                    const SizedBox(height: 2),
                    Text(Formatters.currency(pending),
                        style: AppTextStyles.pageTitle.copyWith(
                            fontSize: 26,
                            color: pending > 0 ? c.danger : c.success)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Collected',
                      style: AppTextStyles.caption.copyWith(color: c.textSub)),
                  const SizedBox(height: 2),
                  Text(Formatters.currency(collected),
                      style: AppTextStyles.h2.copyWith(color: c.success)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            stat('$activeRentals', 'Active rentals'),
            stat('$openReminders', 'Open reminders'),
            stat('$overdue', 'Overdue', color: overdue > 0 ? c.danger : null),
          ]),
          if (awaiting > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Icon(Icons.hourglass_top_outlined, size: 16, color: c.warning),
              const SizedBox(width: AppSpacing.xs),
              Text('$awaiting payment${awaiting == 1 ? '' : 's'} awaiting approval',
                  style: AppTextStyles.caption.copyWith(color: c.warning)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _rentalCard(AppColors c, RentalAgreement r) {
    final vehicles = context.read<RentalVehicleService>();
    final veh = vehicles.byId(r.vehicleId);
    final vlabel = veh == null
        ? 'Vehicle'
        : (veh.regNo.isNotEmpty ? veh.regNo : (veh.chassisNo ?? 'Vehicle'));
    final pending = _pending(r);
    // Reminders worth showing: any open one, plus a little recent context.
    final open = r.installments.where(_isOpen).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RentDetailScreen(rentalId: r.id),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                  '$vlabel  ·  ${r.invoiceNo ?? 'Rental #${r.id}'}',
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
            ),
            _statusChip(c, r),
          ]),
          const SizedBox(height: 2),
          Text(
            [
              if (r.isRecurring)
                '${Formatters.currency(r.periodAmount)} / '
                    '${r.rentalType == 'daily' ? 'day' : 'week'}',
              'Collected ${Formatters.currency(_collected(r))}',
            ].join('  ·  '),
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Text('Pending',
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
            const SizedBox(width: AppSpacing.sm),
            Text(Formatters.currency(pending),
                style: AppTextStyles.bodyStrong.copyWith(
                    color: pending > 0 ? c.danger : c.success)),
            const Spacer(),
            Icon(Icons.chevron_right, color: c.textSub),
          ]),
          if (open.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: c.borderColor),
            const SizedBox(height: AppSpacing.sm),
            for (final inst in open) _reminderRow(c, r, inst),
          ],
        ],
      ),
    );
  }

  Widget _reminderRow(AppColors c, RentalAgreement r, Installment inst) {
    final partial = _paidFor(r, inst) > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(
          _isOverdue(inst)
              ? Icons.error_outline
              : Icons.schedule_outlined,
          size: 16,
          color: _isOverdue(inst) ? c.danger : c.textSub,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Due ${Formatters.date(inst.dueDate)}'
            '${partial ? '  ·  ₹${_paidFor(r, inst)} paid' : ''}',
            style: AppTextStyles.caption.copyWith(color: c.textMain),
          ),
        ),
        Text('₹${_remainingFor(r, inst)}',
            style: AppTextStyles.caption.copyWith(
                color: _isOverdue(inst) ? c.danger : c.textMain,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _statusLabel(RentalAgreement r) {
    if (!r.isActive) return 'Pending approval';
    switch (r.rentalStatus) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Ended';
      case 'seized':
        return 'Seized';
      default:
        return r.rentalStatus;
    }
  }

  Widget _statusChip(AppColors c, RentalAgreement r) {
    final label = _statusLabel(r);
    final Color color = !r.isActive
        ? c.warning
        : r.rentalStatus == 'active'
            ? c.success
            : r.rentalStatus == 'seized'
                ? c.danger
                : c.textSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
