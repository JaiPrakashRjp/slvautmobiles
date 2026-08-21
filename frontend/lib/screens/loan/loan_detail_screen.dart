import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/emi.dart';
import '../../models/loan.dart';
import '../../models/picked_doc.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';

/// Loan detail — summary + an accordion EMI schedule. Each month collapses to a
/// one-line row and expands inline to its payment record (received date, EMI,
/// late penalty, total, part payment, balance, screenshot, remarks, receipt).
class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  static final DateTime _now = DateTime(2026, 6, 2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loans = context.watch<LoanService>();
    final customers = context.read<LoanCustomerService>();
    final vehicles = context.read<LoanVehicleService>();
    final auth = context.read<AuthController>();
    final loan = loans.byId(loanId);

    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final name = customers.byId(loan.customerId)?.fullName ?? 'Unknown';
    final vehicle =
        loan.vehicleId == null ? null : vehicles.byId(loan.vehicleId!);
    final nextEmi = loan.nextDueEmi(_now);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan detail'),
        actions: [
          if (auth.isSuperAdmin && !loan.isClosed && loan.isActive)
            IconButton(
              icon: const Icon(Icons.verified_outlined),
              tooltip: 'Foreclose',
              onPressed: () => _foreclose(context, loans, loan),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              if (!loan.isActive) ...[
                RoleGateBanner(
                  status: loan.status,
                  rejectionReason: loan.rejectionReason,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style:
                                  AppTextStyles.h2.copyWith(color: c.textMain)),
                        ),
                        StatusPill(
                          label: _statusLabel(loan),
                          variant: _statusVariant(loan),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Loan ${Formatters.currency(loan.principal)} · '
                      'EMI ${Formatters.currency(loan.emiAmount)} · ${loan.tenureMonths} mo',
                      style: AppTextStyles.body.copyWith(color: c.textSub),
                    ),
                    if (vehicle != null) ...[
                      const SizedBox(height: 2),
                      Text('🛵 ${vehicle.displayLabel}'
                          '${vehicle.model != null ? ' · ${vehicle.model}' : ''}',
                          style:
                              AppTextStyles.caption.copyWith(color: c.textSub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _stat(context, 'Paid', Formatters.currency(loan.totalPaid)),
                  const SizedBox(width: AppSpacing.md),
                  _stat(context, 'Balance',
                      Formatters.currency(loan.balanceOutstanding)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _stat(context, 'EMI', Formatters.currency(loan.emiAmount)),
                  const SizedBox(width: AppSpacing.md),
                  _stat(
                    context,
                    'Next due',
                    nextEmi == null ? '—' : Formatters.date(nextEmi.dueDate),
                  ),
                ],
              ),
              if (loan.penaltyAccrued > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.dangerTint,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    'Penalty outstanding: ${Formatters.currency(loan.penaltyAccrued)}',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.danger),
                  ),
                ),
              ],
              // ── Seizure controls ──────────────────────────────────────────
              ..._seizeSection(context, loans, loan, auth),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text('EMI schedule',
                        style: AppTextStyles.pageTitle
                            .copyWith(color: c.textMain)),
                  ),
                  Text('${loan.paidEmis}/${loan.tenureMonths} paid',
                      style: AppTextStyles.caption.copyWith(color: c.textSub)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final emi in loan.emis) ...[
                _EmiTile(
                  key: ValueKey(emi.id),
                  emi: emi,
                  now: _now,
                  canManage: loan.isActive && !loan.isClosed && !loan.isSeized,
                  canWaive: auth.isSuperAdmin,
                  onSave: ({
                    required int amount,
                    required int penalty,
                    required DateTime receivedDate,
                    String? remarks,
                    String? screenshotName,
                    Uint8List? screenshotBytes,
                    String? screenshotMime,
                  }) {
                    loans.recordEmiPayment(
                      loan.id,
                      emi.id,
                      amount,
                      penalty: penalty,
                      receivedDate: receivedDate,
                      remarks: remarks,
                      screenshotName: screenshotName,
                      screenshotBytes: screenshotBytes,
                      screenshotMime: screenshotMime,
                    );
                  },
                  onWaive: () => loans.waivePenalty(loan.id, emi.id),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
              RoleGateActions(
                status: loan.status,
                onApprove: () => loans.confirm(
                    loan.id, auth.currentUser?.id ?? 'u_super'),
                onReject: (reason) => loans.reject(
                    loan.id, reason, auth.currentUser?.id ?? 'u_super'),
              ),
              if (loan.isFullyPaid) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.successTint,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                      'Loan fully paid — total paid ${Formatters.currency(loan.totalPaid)}.',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.success)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final c = context.colors;
    return Expanded(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: c.textSub)),
            const SizedBox(height: AppSpacing.xs),
            Text(value,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          ],
        ),
      ),
    );
  }

  Future<void> _foreclose(
      BuildContext context, LoanService loans, Loan loan) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Foreclose loan',
      message:
          'Settle the full balance of ${Formatters.currency(loan.balanceOutstanding)} and close the loan?',
      confirmLabel: 'Foreclose',
    );
    if (ok == true) {
      loans.foreclose(loan.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan foreclosed.')),
        );
      }
    }
  }

  // ── Seizure ─────────────────────────────────────────────────────────────────
  List<Widget> _seizeSection(BuildContext context, LoanService loans, Loan loan,
      AuthController auth) {
    final c = context.colors;
    void snack(String m) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));

    Widget banner(String text, Color color, Color tint) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(text,
              style: AppTextStyles.bodyStrong.copyWith(color: color)),
        );

    // Already seized — repossessed, loan ended.
    if (loan.isSeized) {
      return [
        const SizedBox(height: AppSpacing.lg),
        banner(
          'Vehicle seized${loan.seizeReason != null && loan.seizeReason!.isNotEmpty ? ' — ${loan.seizeReason}' : ''}.',
          c.danger,
          c.dangerTint,
        ),
      ];
    }

    // Seize requested by an admin — awaiting super admin.
    if (loan.isSeizePending) {
      return [
        const SizedBox(height: AppSpacing.lg),
        banner(
          'Seize requested${loan.seizeReason != null && loan.seizeReason!.isNotEmpty ? ' — ${loan.seizeReason}' : ''}. Awaiting Super admin.',
          c.warning,
          c.warningTint,
        ),
        if (auth.isSuperAdmin) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel seize',
                  onPressed: () async {
                    final remarks = await ConfirmationDialog.show(
                      context,
                      title: 'Cancel seize',
                      message: 'The vehicle goes back to the customer and the '
                          'loan continues. Add a remark.',
                      confirmLabel: 'Cancel seize',
                      requireReason: true,
                    );
                    if (remarks is String) {
                      loans.cancelSeize(loan.id, auth.currentUser?.id ?? 'u_super',
                          remarks: remarks);
                      snack('Seize cancelled — back to the customer.');
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Confirm seize',
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Confirm seize',
                      message: 'Repossess the vehicle and end this loan as seized?',
                      confirmLabel: 'Confirm seize',
                      danger: true,
                    );
                    if (ok == true) {
                      loans.confirmSeize(
                          loan.id, auth.currentUser?.id ?? 'u_super');
                      snack('Vehicle seized.');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ];
    }

    // Active loan — offer the Seize button.
    if (loan.isActive && !loan.isClosed) {
      return [
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          label: 'Seize vehicle',
          icon: Icons.gavel_outlined,
          danger: true,
          onPressed: () async {
            final reason = await ConfirmationDialog.show(
              context,
              title: 'Seize vehicle',
              message: auth.isSuperAdmin
                  ? 'Repossess the vehicle from the customer? Give a reason.'
                  : 'Request to seize the vehicle. A Super admin confirms it. '
                      'Give a reason.',
              confirmLabel: 'Seize',
              danger: true,
              requireReason: true,
            );
            if (reason is String && reason.isNotEmpty) {
              loans.requestSeize(loan.id, reason,
                  superAdmin: auth.isSuperAdmin,
                  byUserId: auth.currentUser?.id ?? 'u_super');
              snack(auth.isSuperAdmin
                  ? 'Vehicle seized.'
                  : 'Seize requested — awaiting Super admin.');
            }
          },
        ),
      ];
    }
    return const [];
  }
}

String _statusLabel(Loan l) => l.isSeized
    ? 'Seized'
    : l.isFullyPaid
        ? 'Paid'
        : l.isSeizePending
            ? 'Seize pending'
            : l.loanStatus == 'overdue'
                ? 'Overdue'
                : l.loanStatus == 'rejected'
                    ? 'Rejected'
                    : 'Active';

PillVariant _statusVariant(Loan l) =>
    l.isSeized || l.loanStatus == 'overdue' || l.loanStatus == 'rejected'
        ? PillVariant.danger
        : l.isFullyPaid
            ? PillVariant.success
            : l.isSeizePending
                ? PillVariant.warning
                : PillVariant.info;

typedef _SavePayment = void Function({
  required int amount,
  required int penalty,
  required DateTime receivedDate,
  String? remarks,
  String? screenshotName,
  Uint8List? screenshotBytes,
  String? screenshotMime,
});

/// A collapsible EMI row: a one-line header that expands to the payment record.
class _EmiTile extends StatefulWidget {
  const _EmiTile({
    super.key,
    required this.emi,
    required this.now,
    required this.canManage,
    required this.canWaive,
    required this.onSave,
    required this.onWaive,
  });

  final Emi emi;
  final DateTime now;
  final bool canManage;
  final bool canWaive;
  final _SavePayment onSave;
  final VoidCallback onWaive;

  @override
  State<_EmiTile> createState() => _EmiTileState();
}

class _EmiTileState extends State<_EmiTile> {
  bool _open = false;
  final _penaltyCtrl = TextEditingController();
  final _payCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime? _receivedDate;
  String? _screenshotName;
  PickedDoc? _screenshot;

  @override
  void dispose() {
    _penaltyCtrl.dispose();
    _payCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) _initForm();
    });
  }

  void _initForm() {
    final e = widget.emi;
    _penaltyCtrl.text = e.penalty > 0 ? '${e.penalty}' : '';
    _receivedDate = e.receivedDate ?? widget.now;
    _remarksCtrl.text = e.remarks ?? '';
    _screenshotName = e.screenshotName;
    _payCtrl.text = '${_balance()}';
  }

  int get _penalty => int.tryParse(_penaltyCtrl.text.trim()) ?? 0;
  int get _paying => int.tryParse(_payCtrl.text.trim()) ?? 0;
  int get _total => widget.emi.amountDue + _penalty;
  int _balance() => (_total - widget.emi.amountPaid).clamp(0, _total);
  int get _newBalance => (_total - widget.emi.amountPaid - _paying).clamp(0, _total);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate ?? widget.now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked != null) setState(() => _receivedDate = picked);
  }

  Future<void> _attach(PickedDoc? doc) async {
    if (doc != null) {
      setState(() {
        _screenshot = doc;
        _screenshotName = doc.name;
      });
    }
  }

  void _save() {
    if (_paying <= 0 && _penalty == widget.emi.penalty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount to record.')),
      );
      return;
    }
    widget.onSave(
      amount: _paying,
      penalty: _penalty,
      receivedDate: _receivedDate ?? widget.now,
      remarks: _remarksCtrl.text.trim(),
      screenshotName: _screenshotName,
      screenshotBytes: _screenshot?.bytes,
      screenshotMime: _screenshot?.mimeType ?? PickedDoc.mimeFor(_screenshotName ?? ''),
    );
    setState(() => _open = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('EMI ${widget.emi.sequenceNumber}: '
          '${Formatters.currency(_paying)} recorded.')),
    );
  }

  void _print() {
    // Receipt generation lands with the loan backend; acknowledge for now.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt for EMI ${widget.emi.sequenceNumber} '
          '(${Formatters.currency(widget.emi.amountPaid)} paid).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.emi;
    final status = e.statusAt(widget.now);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Collapsed header (always visible) ──────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(_open ? Icons.expand_more : Icons.chevron_right,
                      color: c.textSub, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EMI ${e.sequenceNumber} · ${Formatters.date(e.dueDate)}',
                            style:
                                AppTextStyles.body.copyWith(color: c.textMain)),
                        const SizedBox(height: 2),
                        Text(
                          e.penalty > 0
                              ? '${Formatters.currency(e.totalDue)} · incl. penalty ${Formatters.currency(e.penalty)}'
                              : Formatters.currency(e.amountDue),
                          style: AppTextStyles.caption.copyWith(
                              color: e.penalty > 0 ? c.danger : c.textSub),
                        ),
                        if (e.isPartial) ...[
                          const SizedBox(height: 2),
                          Text('Paid ${Formatters.currency(e.amountPaid)} · '
                              'balance ${Formatters.currency(e.remaining)}',
                              style: AppTextStyles.caption
                                  .copyWith(color: c.textSub)),
                        ],
                      ],
                    ),
                  ),
                  if (e.isPaid)
                    Icon(Icons.check_circle, color: c.success, size: 20)
                  else
                    StatusPill.forSchedule(status),
                ],
              ),
            ),
          ),
          // ── Expanded body ──────────────────────────────────────────────
          if (_open) ...[
            Divider(height: 1, color: c.borderColor),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: e.isPaid ? _paidView(context) : _payForm(context),
            ),
          ],
        ],
      ),
    );
  }

  // Read-only receipt view for a cleared month.
  Widget _paidView(BuildContext context) {
    final c = context.colors;
    final e = widget.emi;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: AppTextStyles.caption.copyWith(color: c.textSub)),
              Text(v,
                  style: AppTextStyles.body.copyWith(color: c.textMain)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Paid on',
            e.receivedDate == null ? '—' : Formatters.date(e.receivedDate!)),
        row('Amount', Formatters.currency(e.amountDue)),
        if (e.penalty > 0) row('Penalty', Formatters.currency(e.penalty)),
        row('Total', Formatters.currency(e.totalDue)),
        if (e.screenshotName != null) row('Screenshot', e.screenshotName!),
        if (e.remarks != null && e.remarks!.isNotEmpty)
          row('Remarks', e.remarks!),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
            label: 'Print receipt',
            icon: Icons.print_outlined,
            onPressed: _print),
      ],
    );
  }

  // The payment record form for an open month.
  Widget _payForm(BuildContext context) {
    final c = context.colors;
    final e = widget.emi;
    if (!widget.canManage) {
      return Text('Approve the loan to start collecting EMIs.',
          style: AppTextStyles.caption.copyWith(color: c.textSub));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateField(
          label: 'Received date',
          value: _receivedDate,
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ReadonlyField(
                  label: 'EMI amount',
                  value: Formatters.currency(e.amountDue)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: 'Penalty',
                prefixText: '₹ ',
                controller: _penaltyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Calc block: total / paying / balance.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            children: [
              _calcRow(c, 'Total incl. penalty',
                  Formatters.currency(_total), big: true),
              if (e.amountPaid > 0)
                _calcRow(c, 'Already paid',
                    Formatters.currency(e.amountPaid)),
              _calcRow(c, 'Paying now', Formatters.currency(_paying)),
              Divider(color: c.onPrimary.withValues(alpha: 0.2)),
              _calcRow(c, 'Balance carried',
                  Formatters.currency(_newBalance)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Paying now',
          prefixText: '₹ ',
          controller: _payCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        // Screenshot
        InkWell(
          onTap: () async => _attach(await pickFileDoc()),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: c.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: c.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _screenshotName ?? 'Attach payment screenshot',
                    style: AppTextStyles.body.copyWith(
                        color: _screenshotName == null
                            ? c.textSub
                            : c.textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_screenshotName == null)
                  Icon(Icons.upload_outlined, color: c.textSub, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Remarks',
          hint: 'Any note about this payment',
          controller: _remarksCtrl,
          maxLines: 2,
        ),
        if (widget.canWaive && e.penalty > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onWaive,
              child: const Text('Waive penalty'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                  label: 'Print',
                  icon: Icons.print_outlined,
                  onPressed: _print),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: PrimaryButton(label: 'Save payment', onPressed: _save),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calcRow(AppColors c, String label, String value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.onPrimary.withValues(alpha: big ? 1 : 0.8),
                  fontSize: big ? 13 : 12.5)),
          Text(value,
              style: TextStyle(
                  color: c.onPrimary,
                  fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                  fontSize: big ? 18 : 14)),
        ],
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(color: c.textSub)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 14),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: c.borderColor),
          ),
          child: Text(value,
              style: AppTextStyles.body.copyWith(color: c.textSub)),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(color: c.textSub)),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: c.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Select date' : Formatters.date(value!),
                    style: AppTextStyles.body.copyWith(
                        color: value == null ? c.textSub : c.textMain),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, color: c.textSub, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
