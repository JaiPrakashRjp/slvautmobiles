import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/installment.dart';
import '../../models/rental_agreement.dart';
import '../../models/sale_payment.dart';
import '../../services/api_rental_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';
import '../pdf_preview_screen.dart';

/// Full rental detail: summary, rent invoice, collections (reminders + manual
/// payment), payment history, confirm-complete, seize, and approval banners.
/// Mirrors the sale detail screen, on the rental services.
class RentDetailScreen extends StatefulWidget {
  const RentDetailScreen({super.key, required this.rentalId});

  final String rentalId;

  @override
  State<RentDetailScreen> createState() => _RentDetailScreenState();
}

class _RentDetailScreenState extends State<RentDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_busy) context.read<RentalAgreementService>().refresh();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<RentalAgreementService>().refresh(),
      context.read<RentalVehicleService>().refresh(),
      context.read<RentalCustomerService>().refresh(),
    ]);
  }

  RentalAgreementService get _rentals => context.read<RentalAgreementService>();

  bool get _isSuper => context.read<AuthController>().isSuperAdmin;
  String get _uid => context.read<AuthController>().currentUser?.id ?? '';

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return (ok == true && text.isNotEmpty) ? text : null;
  }

  // ── Collections ────────────────────────────────────────────────────────────
  Future<void> _setReminder(RentalAgreement r) async {
    DateTime date = DateTime.now().add(const Duration(days: 5));
    final amountCtrl = TextEditingController();
    final remaining = r.remainingAmount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Set reminder'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                helperText: remaining > 0 ? 'Remaining: ₹$remaining' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Due ${Formatters.date(date)}')),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                child: const Text('Pick date'),
              ),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Set')),
          ],
        ),
      ),
    );
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (ok != true || amount <= 0 || !mounted) return;
    await _run(() => _rentals.addReminder(r.id, dueDate: date, amount: amount),
        'Reminder set.');
  }

  Future<void> _recordPayment(RentalAgreement r, Installment inst) =>
      _payDialog('Record payment',
          amount: inst.amount,
          onSubmit: (amt, shot, name, mime, paidOn) => _rentals.submitPayment(
              inst.id,
              amount: amt,
              screenshot: shot,
              filename: name,
              mimeType: mime,
              paidOn: paidOn));

  Future<void> _manualPay(RentalAgreement r) =>
      _payDialog('Manual payment',
          amount: null,
          onSubmit: (amt, shot, name, mime, paidOn) =>
              _rentals.submitManualPayment(r.id,
                  amount: amt,
                  screenshot: shot,
                  filename: name,
                  mimeType: mime,
                  paidOn: paidOn));

  Future<void> _payDialog(
    String title, {
    required int? amount,
    required Future<void> Function(
            int amt, Uint8List bytes, String name, String? mime, DateTime paidOn)
        onSubmit,
  }) async {
    final amountCtrl = TextEditingController(text: amount == null ? '' : '$amount');
    _Shot? shot;
    DateTime paidOn = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Amount received', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: Text(shot == null ? 'Attach screenshot' : shot!.name,
                      overflow: TextOverflow.ellipsis)),
              TextButton.icon(
                onPressed: () async {
                  final img =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) {
                    final bytes = await img.readAsBytes();
                    setLocal(() => shot = _Shot(img.name, bytes, img.mimeType));
                  }
                },
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Screenshot'),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Paid on: ${Formatters.date(paidOn)}')),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: paidOn,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setLocal(() => paidOn = picked);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('Date'),
              ),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit')),
          ],
        ),
      ),
    );
    final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (ok != true || !mounted) return;
    if (amt <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (shot == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Attach a payment screenshot')));
      return;
    }
    await _run(
        () => onSubmit(amt, shot!.bytes, shot!.name, shot!.mime, paidOn),
        _isSuper ? 'Payment recorded.' : 'Payment submitted for approval.');
  }

  void _viewShot(int docId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DocumentPreviewScreen(
        title: 'Payment screenshot',
        fileName: 'payment_$docId.jpg',
        loader: () => _rentals.screenshotBytes(docId),
      ),
    ));
  }

  void _paymentHistory(RentalAgreement r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.colors;
        final payments = r.payments;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment history',
                    style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                const SizedBox(height: AppSpacing.md),
                if (payments.isEmpty)
                  Text('No payments recorded yet.',
                      style: AppTextStyles.body.copyWith(color: c.textSub))
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: payments.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.borderColor),
                      itemBuilder: (_, i) => _historyRow(payments[i], c),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Divider(color: c.borderColor),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Text('Remaining balance',
                          style:
                              AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
                      const Spacer(),
                      Text(Formatters.currency(r.remainingAmount),
                          style: AppTextStyles.h2.copyWith(
                              color: r.remainingAmount > 0
                                  ? c.danger
                                  : c.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyRow(SalePayment p, AppColors c) {
    final (label, color) = p.isApproved
        ? ('Approved', c.success)
        : p.isRejected
            ? ('Rejected', c.danger)
            : ('Pending', c.warning);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(Formatters.currency(p.amount),
                      style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: AppTextStyles.caption.copyWith(color: color)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  [
                    p.isManual ? 'Manual' : 'Installment',
                    if (p.paidAt != null) Formatters.date(p.paidAt!),
                  ].join('  ·  '),
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                ),
              ],
            ),
          ),
          if (p.documentIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              onPressed: () => _viewShot(p.documentIds.first),
            ),
        ],
      ),
    );
  }

  Future<void> _openInvoice(RentalAgreement r) async {
    final pdf = context.read<PdfService>();
    final customer = context.read<RentalCustomerService>().byId(r.customerId);
    final vehicle = context.read<RentalVehicleService>().byId(r.vehicleId);
    if (customer == null || vehicle == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfPreviewScreen(
        title: 'Rent invoice',
        fileName: 'rent-${r.invoiceNo ?? r.id}.pdf',
        builder: () =>
            pdf.rentInvoiceBytes(rental: r, customer: customer, vehicle: vehicle),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = context.watch<RentalAgreementService>().byId(widget.rentalId);
    final customer =
        r == null ? null : context.read<RentalCustomerService>().byId(r.customerId);
    final vehicle =
        r == null ? null : context.read<RentalVehicleService>().byId(r.vehicleId);
    final canModify = r != null &&
        r.isActive &&
        (_isSuper || r.createdBy == _uid);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Rental detail'),
        actions: [
          if (r != null && customer != null && vehicle != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Rent invoice',
              onPressed: () => _openInvoice(r),
            ),
        ],
      ),
      body: SafeArea(
        child: r == null
            ? Center(
                child: Text('Rental not found',
                    style: AppTextStyles.body.copyWith(color: c.textSub)))
            : ResponsiveBody(
                maxFormWidth: 560,
                phone: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(context.screenHPadding),
                    children: [
                      if (!r.isActive) ...[
                        RoleGateBanner(
                            status: r.status, rejectionReason: r.rejectionReason),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (r.isSeizePending) ...[
                        _approvalBanner(
                          'Seize requested — awaiting approval',
                          r.seizeReason,
                          onApprove: () =>
                              _run(() => _rentals.approveSeize(r.id), 'Seize approved.'),
                          onReject: () async {
                            final reason =
                                await _askReason('Reject seize', 'Reason');
                            if (reason != null) {
                              await _run(() => _rentals.rejectSeize(r.id, reason),
                                  'Seize rejected.');
                            }
                          },
                          c: c,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (r.isEditPending) ...[
                        _approvalBanner(
                          'Edit pending approval',
                          _editSummary(r),
                          onApprove: () =>
                              _run(() => _rentals.approveEdit(r.id), 'Edit approved.'),
                          onReject: () async {
                            final reason =
                                await _askReason('Reject edit', 'Reason');
                            if (reason != null) {
                              await _run(() => _rentals.rejectEdit(r.id, reason),
                                  'Edit rejected.');
                            }
                          },
                          c: c,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (canModify && r.remainingAmount <= 0 && !r.isCompleted) ...[
                        _completeBanner(r, c),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _summaryCard(r, customer, vehicle, c),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        onTap: () => _paymentHistory(r),
                        child: Row(children: [
                          Icon(Icons.receipt_long_outlined, color: c.primary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: Text('Payment history',
                                  style: AppTextStyles.bodyStrong
                                      .copyWith(color: c.textMain))),
                          Text('${r.payments.length}',
                              style: AppTextStyles.body.copyWith(color: c.textSub)),
                          Icon(Icons.chevron_right, color: c.textSub),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Reminders',
                          style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                      if (canModify && !r.isCompleted) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _manualPay(r),
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: const Text('Manual pay'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _setReminder(r),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Set reminder'),
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      if (r.installments.isEmpty)
                        Text('No reminders yet.',
                            style: AppTextStyles.body.copyWith(color: c.textSub))
                      else
                        for (final inst in r.installments) ...[
                          _reminderTile(r, inst, c, canModify),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      // Seize (active rental only)
                      if (canModify &&
                          r.rentalStatus == 'active' &&
                          r.seizeStage == null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final reason = await _askReason(
                                  'Seize vehicle', 'Reason for seizure');
                              if (reason != null) {
                                await _run(() => _rentals.seize(r.id, reason),
                                    'Seize requested.');
                              }
                            },
                            icon: Icon(Icons.gavel_rounded, color: c.danger, size: 18),
                            label: Text('Seize vehicle',
                                style: TextStyle(color: c.danger)),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _editSummary(RentalAgreement r) {
    final e = r.pendingEdit;
    if (e == null) return '';
    final total = (e['total_amount'] as num?)?.round();
    final adv = (e['advance_amount'] as num?)?.round();
    return 'New total ₹$total · advance ₹$adv';
  }

  Widget _summaryCard(RentalAgreement r, customer, vehicle, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(r.invoiceNo ?? 'Rental #${r.id}',
                    style: AppTextStyles.h2.copyWith(color: c.textMain))),
            StatusPill.forEntity(r.status),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (customer != null) _row('Customer', customer.fullName, c),
          if (vehicle != null)
            _row(
                'Vehicle',
                vehicle.regNo.isNotEmpty
                    ? vehicle.regNo
                    : (vehicle.chassisNo ?? '—'),
                c),
          if (r.startDate != null)
            _row('Start date', Formatters.date(r.startDate!), c),
          _row('Total', Formatters.currency(r.totalAmount), c),
          _row('Advance', Formatters.currency(r.advance), c),
          _row('Remaining',
              r.remainingAmount > 0
                  ? Formatters.currency(r.remainingAmount)
                  : 'Paid',
              c,
              highlight: r.remainingAmount > 0),
          _row('Status', r.rentalStatus, c),
          if (r.remarks != null && r.remarks!.isNotEmpty)
            _row('Remarks', r.remarks!, c),
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppColors c, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 82,
            child: Text(label,
                style: AppTextStyles.caption.copyWith(color: c.textSub))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(value,
                style: AppTextStyles.body.copyWith(
                    color: highlight ? c.danger : c.textMain,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.normal))),
      ]),
    );
  }

  Widget _reminderTile(
      RentalAgreement r, Installment inst, AppColors c, bool canModify) {
    final pending = r.pendingPaymentFor(inst.id);
    final actions = <Widget>[];
    if (pending != null) {
      if (_isSuper) {
        actions.add(TextButton(
            onPressed: _busy
                ? null
                : () => _run(() => _rentals.approvePayment(pending.id),
                    'Payment approved.'),
            child: const Text('Approve')));
        actions.add(TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final reason =
                        await _askReason('Decline payment', 'Reason');
                    if (reason != null) {
                      await _run(
                          () => _rentals.declinePayment(pending.id, reason),
                          'Payment declined.');
                    }
                  },
            child: const Text('Decline')));
      } else {
        actions.add(Text('₹${pending.amount} awaiting approval',
            style: AppTextStyles.caption.copyWith(color: c.textSub)));
      }
    } else if (canModify && !r.isCompleted && !inst.isPaid && !inst.isCancelled) {
      final due = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
      final today = DateTime.now();
      if (due.isAfter(DateTime(today.year, today.month, today.day))) {
        actions.add(Text('Opens ${Formatters.date(inst.dueDate)}',
            style: AppTextStyles.caption.copyWith(color: c.textSub)));
      } else {
        actions.add(TextButton(
            onPressed: _busy ? null : () => _recordPayment(r, inst),
            child: const Text('Record payment')));
        actions.add(TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final reason =
                        await _askReason('Cancel reminder', 'Why deferred?');
                    if (reason != null) {
                      await _run(
                          () => _rentals.cancelReminder(inst.id, reason),
                          'Reminder cancelled.');
                    }
                  },
            child: const Text('Cancel')));
      }
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('₹${inst.amount}  ·  due ${Formatters.date(inst.dueDate)}',
                  style: AppTextStyles.body.copyWith(color: c.textMain))),
          _chip(inst, pending, c),
        ]),
        if (inst.isCancelled && inst.cancelReason != null) ...[
          const SizedBox(height: 4),
          Text('Deferred: ${inst.cancelReason}',
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: 8, runSpacing: 4, children: actions),
        ],
      ]),
    );
  }

  Widget _chip(Installment inst, SalePayment? pending, AppColors c) {
    String label;
    Color color;
    if (inst.isPaid) {
      label = 'Paid';
      color = c.success;
    } else if (pending != null) {
      label = 'Pending approval';
      color = c.primary;
    } else if (inst.isCancelled) {
      label = 'Cancelled';
      color = c.textSub;
    } else {
      label = 'Pending';
      color = c.textSub;
    }
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

  Widget _completeBanner(RentalAgreement r, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.success.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_outline, color: c.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text('Rent fully collected',
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textMain))),
        ]),
        const SizedBox(height: 4),
        Text('Confirm this rental as complete.',
            style: AppTextStyles.caption.copyWith(color: c.textSub)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() => _rentals.complete(r.id), 'Rental completed.'),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Confirm complete rent'),
          ),
        ),
      ]),
    );
  }

  Widget _approvalBanner(String title, String? reason,
      {required VoidCallback onApprove,
      required VoidCallback onReject,
      required AppColors c}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(reason, style: AppTextStyles.caption.copyWith(color: c.textSub)),
        ],
        if (_isSuper) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: onReject, child: const Text('Reject'))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: FilledButton(
                    onPressed: onApprove, child: const Text('Approve'))),
          ]),
        ] else ...[
          const SizedBox(height: 4),
          Text('Awaiting super-admin approval',
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
        ],
      ]),
    );
  }
}

class _Shot {
  _Shot(this.name, this.bytes, this.mime);
  final String name;
  final Uint8List bytes;
  final String? mime;
}
