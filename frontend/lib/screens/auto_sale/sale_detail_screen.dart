import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/installment.dart';
import '../../models/sale.dart';
import '../../models/sale_payment.dart';
import '../../services/customer_service.dart';
import '../../services/pdf_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/sale_detail_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/role_gate_banner.dart';
// import '../../widgets/secondary_button.dart'; // used only by hidden payoff receipt
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';

// ── Receipt helpers (inline) ──────────────────────────────────────────────

/// Full sale detail: summary, installment history, pay-off, reminders.
class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SaleDetailViewModel(
        saleId: saleId,
        sales: context.read<SaleService>(),
        customers: context.read<CustomerService>(),
        vehicles: context.read<VehicleService>(),
        auth: context.read<AuthController>(),
      ),
      child: const _SaleDetailView(),
    );
  }
}

class _SaleDetailView extends StatefulWidget {
  const _SaleDetailView();

  @override
  State<_SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<_SaleDetailView> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh on open so approvals / reminders made elsewhere show without
    // a re-login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  /// Re-pull the sale (+ its vehicle, customer and reminder log) from the
  /// server. Backs both the auto-refresh on open and pull-to-refresh.
  Future<void> _refresh() async {
    final vm = context.read<SaleDetailViewModel>();
    await Future.wait([
      context.read<SaleService>().refresh(),
      context.read<VehicleService>().refresh(),
      context.read<CustomerService>().refresh(),
    ]);
    if (!mounted) return;
    await vm.loadReminders();
  }

  Future<void> _act(BuildContext context, Future<void> Function() action,
      String okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<String?> _askReason(
      BuildContext context, String title, String hint) async {
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

  Future<void> _setReminder(BuildContext context, SaleDetailViewModel vm) async {
    DateTime date = DateTime.now().add(const Duration(days: 5));
    final amountCtrl = TextEditingController();
    // A reminder/collection can't be for more than what's still owed.
    final remaining = vm.sale?.remainingAmount ?? 0;
    String? error;
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
                errorText: error,
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
                onPressed: () {
                  final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (amt <= 0) {
                    setLocal(() => error = 'Enter an amount');
                    return;
                  }
                  if (remaining > 0 && amt > remaining) {
                    setLocal(() => error = 'Cannot exceed remaining ₹$remaining');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Set')),
          ],
        ),
      ),
    );
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (ok != true || amount <= 0 || !context.mounted) return;
    await _act(context, () => vm.addReminder(date, amount), 'Reminder set.');
  }

  Future<void> _callCustomer(SaleDetailViewModel vm) async {
    final phone = vm.sale?.customerWhatsapp.trim() ?? '';
    final number = phone.isNotEmpty ? phone : (vm.customer?.phone ?? '');
    if (number.isEmpty) return;
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _recordPayment(
      BuildContext context, SaleDetailViewModel vm, Installment inst) async {
    final amountCtrl = TextEditingController(text: '${inst.amount}');
    _PickedShot? shot;
    DateTime paidOn = DateTime.now(); // date the payment was actually made
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Amount received', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  shot == null ? 'Attach payment screenshot' : shot!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (img != null) {
                    final bytes = await img.readAsBytes();
                    setLocal(
                        () => shot = _PickedShot(img.name, bytes, img.mimeType));
                  }
                },
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Screenshot'),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text('Paid on: ${Formatters.date(paidOn)}'),
              ),
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
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (ok != true || !context.mounted) return;
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (shot == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Attach a payment screenshot')));
      return;
    }
    await _act(
      context,
      () => vm.submitPayment(inst.id, amount, shot!.bytes, shot!.name, shot!.mime,
          paidOn: paidOn),
      vm.isSuperAdmin ? 'Payment recorded.' : 'Payment submitted for approval.',
    );
  }

  void _viewScreenshot(BuildContext context, SaleDetailViewModel vm, int docId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DocumentPreviewScreen(
        title: 'Payment screenshot',
        fileName: 'payment_$docId.jpg',
        loader: () => vm.screenshotBytes(docId),
      ),
    ));
  }

  /// Confirm a fully-paid sale as sold — pops a confirmation, then flips the
  /// sale's `sold` flag (which hides the Seize option).
  Future<void> _confirmSold(BuildContext context, SaleDetailViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm sold'),
        content: const Text(
            'The balance is fully cleared. Mark this sale as sold? '
            'The vehicle can no longer be seized once confirmed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm sold')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _act(context, () => vm.confirmSold(), 'Sale confirmed as sold.');
  }

  /// Record a standalone (manual) payment: amount + screenshot, not tied to any
  /// reminder/installment. Shows up in the payment history.
  Future<void> _manualPay(BuildContext context, SaleDetailViewModel vm) async {
    final amountCtrl = TextEditingController();
    _PickedShot? shot;
    DateTime paidOn = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Manual payment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Amount received', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  shot == null ? 'Attach payment screenshot' : shot!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final img = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (img != null) {
                    final bytes = await img.readAsBytes();
                    setLocal(
                        () => shot = _PickedShot(img.name, bytes, img.mimeType));
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
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    amountCtrl.dispose();
    if (ok != true || !context.mounted) return;
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (shot == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Attach a payment screenshot')));
      return;
    }
    await _act(
      context,
      () => vm.submitManualPayment(amount, shot!.bytes, shot!.name, shot!.mime,
          paidOn: paidOn),
      vm.isSuperAdmin ? 'Payment recorded.' : 'Payment submitted for approval.',
    );
  }

  /// Bottom sheet listing every payment (manual + installment) with its status
  /// and a link to the proof screenshot.
  void _paymentHistory(BuildContext context, SaleDetailViewModel vm) {
    final payments = vm.sale?.payments ?? const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment history',
                    style:
                        AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                const SizedBox(height: AppSpacing.md),
                if (payments.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('No payments recorded yet.',
                        style: AppTextStyles.body.copyWith(color: c.textSub)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: payments.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.borderColor),
                      itemBuilder: (_, i) {
                        final p = payments[i];
                        final canReview = vm.isSuperAdmin && p.isPending;
                        return _PaymentHistoryRow(
                          payment: p,
                          onView: (docId) =>
                              _viewScreenshot(context, vm, docId),
                          c: c,
                          onApprove: canReview
                              ? () async {
                                  Navigator.pop(ctx);
                                  await _act(
                                      context,
                                      () => vm.approvePayment(p.id),
                                      'Payment approved.');
                                }
                              : null,
                          onDecline: canReview
                              ? () async {
                                  Navigator.pop(ctx);
                                  final r = await _askReason(context,
                                      'Decline payment', 'Reason for declining');
                                  if (r == null || !context.mounted) return;
                                  await _act(
                                      context,
                                      () => vm.declinePayment(p.id, r),
                                      'Payment declined.');
                                }
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(Installment inst, SalePayment? pending, AppColors c) {
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
    } else if (inst.isInProgress) {
      label = 'In progress';
      color = c.primary;
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

  Widget _reminderTile(BuildContext context, SaleDetailViewModel vm, Sale sale,
      Installment inst, AppColors c) {
    final pending = sale.pendingPaymentFor(inst.id);
    final actions = <Widget>[];
    if (pending != null) {
      if (vm.isSuperAdmin) {
        if (pending.documentIds.isNotEmpty) {
          actions.add(TextButton.icon(
            onPressed: () =>
                _viewScreenshot(context, vm, pending.documentIds.first),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('Screenshot'),
          ));
        }
        actions.add(TextButton(
            onPressed:
                vm.busy ? null : () => _act(context, () => vm.approvePayment(pending.id), 'Payment approved.'),
            child: const Text('Approve')));
        actions.add(TextButton(
            onPressed: vm.busy
                ? null
                : () async {
                    final r = await _askReason(
                        context, 'Decline payment', 'Reason for declining');
                    if (r == null || !context.mounted) return;
                    await _act(context, () => vm.declinePayment(pending.id, r),
                        'Payment declined.');
                  },
            child: const Text('Decline')));
      } else {
        actions.add(Text('₹${pending.amount} awaiting super-admin approval',
            style: AppTextStyles.caption.copyWith(color: c.textSub)));
      }
    } else if (vm.canModify &&
        !vm.isClosed &&
        !inst.isPaid &&
        !inst.isCancelled) {
      if (inst.isPending) {
        final due = DateTime(
            inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (due.isAfter(today)) {
          // not due yet — the call opens on the due date
          actions.add(Text(
            'Scheduled — call opens on ${Formatters.date(inst.dueDate)}',
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ));
        } else {
          actions.add(TextButton.icon(
            onPressed: vm.busy
                ? null
                : () => _act(context, () => vm.takeCall(inst.id),
                    'Call assigned to you.'),
            icon: const Icon(Icons.headset_mic_outlined, size: 18),
            label: const Text('Take call'),
          ));
        }
      } else if (inst.isInProgress) {
        actions.add(IconButton(
          onPressed: () => _callCustomer(vm),
          icon: const Icon(Icons.call),
          tooltip: 'Call customer',
        ));
        actions.add(TextButton(
            onPressed: vm.busy ? null : () => _recordPayment(context, vm, inst),
            child: const Text('Record payment')));
        actions.add(TextButton(
            onPressed: vm.busy
                ? null
                : () async {
                    final r = await _askReason(
                        context, 'Cancel reminder', 'Why is it deferred?');
                    if (r == null || !context.mounted) return;
                    await _act(context, () => vm.cancelReminder(inst.id, r),
                        'Reminder cancelled.');
                  },
            child: const Text('Cancel')));
      }
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('₹${inst.amount}  ·  due ${Formatters.date(inst.dueDate)}',
                style: AppTextStyles.body.copyWith(color: c.textMain)),
          ),
          _statusChip(inst, pending, c),
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<SaleService>();
    final vm = context.watch<SaleDetailViewModel>();
    final sale = vm.sale;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Sale detail'),
        actions: [
          if (sale != null && vm.customer != null && vm.vehicle != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Sale invoice',
              onPressed: () => context.read<PdfService>().previewInvoice(
                    sale: sale,
                    customer: vm.customer!,
                    vehicle: vm.vehicle!,
                  ),
            ),
        ],
      ),
      body: SafeArea(
        child: sale == null
            ? Center(
                child: Text('Sale not found',
                    style: AppTextStyles.body.copyWith(color: c.textSub)))
            : ResponsiveBody(
                maxFormWidth: 560,
                phone: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    // ── Pending / rejected banner ───────────────────────────
                    if (!sale.isActive) ...[
                      RoleGateBanner(
                        status: sale.status,
                        rejectionReason: sale.rejectionReason,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // ── Pending seize approval (admin requested) ────────────
                    if (sale.isSeizePending) ...[
                      _SeizeApprovalBanner(
                        reason: sale.seizeReason,
                        canReview: vm.isSuperAdmin,
                        onApprove: () => _act(
                            context, () => vm.approveSeize(), 'Seize approved.'),
                        onReject: () async {
                          final r = await _askReason(
                              context, 'Reject seize', 'Reason for rejecting');
                          if (r == null || !context.mounted) return;
                          await _act(context, () => vm.rejectSeize(r),
                              'Seize rejected.');
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // ── Pending unsell approval (admin requested) ───────────
                    if (sale.isUnsellPending) ...[
                      _ApprovalBanner(
                        icon: Icons.undo_rounded,
                        title: 'Unsell requested — awaiting approval',
                        reason: sale.unsellReason,
                        canReview: vm.isSuperAdmin,
                        onApprove: () => _act(context, () => vm.approveUnsell(),
                            'Unsell approved.'),
                        onReject: () async {
                          final r = await _askReason(
                              context, 'Reject unsell', 'Reason for rejecting');
                          if (r == null || !context.mounted) return;
                          await _act(context, () => vm.rejectUnsell(r),
                              'Unsell rejected.');
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // ── Fully paid → confirm as sold ────────────────────────
                    if (vm.canConfirmSold) ...[
                      _ConfirmSoldBanner(
                        onConfirm: () => _confirmSold(context, vm),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // ── Summary card ────────────────────────────────────────
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sale.invoiceNo ?? 'Sale #${sale.id}',
                                  style: AppTextStyles.h2
                                      .copyWith(color: c.textMain),
                                ),
                              ),
                              StatusPill.forEntity(sale.status),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (vm.customer != null)
                            _SummaryRow(
                                label: 'Customer',
                                value: vm.customer!.fullName,
                                c: c),
                          if (vm.vehicle != null)
                            _SummaryRow(
                                label: 'Vehicle',
                                value: vm.vehicle!.regNo.isNotEmpty
                                    ? vm.vehicle!.regNo
                                    : (vm.vehicle!.chassisNo ?? '—'),
                                c: c),
                          _SummaryRow(
                              label: 'Deposit',
                              value: sale.depositType.label,
                              c: c),
                          if (sale.financerName != null &&
                              sale.financerName!.isNotEmpty)
                            _SummaryRow(
                                label: 'Financer',
                                value: sale.financerName!,
                                c: c),
                          if (sale.saleDate != null)
                            _SummaryRow(
                                label: 'Sale date',
                                value: Formatters.date(sale.saleDate!),
                                c: c),
                          if (sale.salePrice != null)
                            _SummaryRow(
                                label: 'Total amount',
                                value: Formatters.currency(sale.salePrice!),
                                c: c),
                          // HP (loan) amount is deducted from the total.
                          if (sale.hpAmount != null)
                            _SummaryRow(
                                label: 'HP amount',
                                value:
                                    '− ${Formatters.currency(sale.hpAmount!)}',
                                c: c),
                          _SummaryRow(
                              label: 'Down payment',
                              value: Formatters.currency(sale.advance),
                              c: c),
                          // Down-payment / loan sale: installment balance
                          // (Total − HP − Down payment).
                          if (sale.mode == PaymentMode.installments)
                            _SummaryRow(
                                label: 'Remaining',
                                value: sale.remainingAmount > 0
                                    ? Formatters.currency(sale.remainingAmount)
                                    : 'Paid',
                                c: c,
                                highlight: sale.remainingAmount > 0),
                          _SummaryRow(
                              label: 'Status',
                              value: vm.isSold
                                  ? 'Sold'
                                  : vm.isClosed
                                      ? 'Paid'
                                      : sale.saleStatus,
                              c: c),
                          if (sale.remarks != null &&
                              sale.remarks!.isNotEmpty)
                            _SummaryRow(
                                label: 'Remarks',
                                value: sale.remarks!,
                                c: c),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Pay off / payoff receipt ─ hidden for this release ───
                    /*
                    if (sale.mode == PaymentMode.installments) ...[
                      if (vm.isClosed && vm.customer != null && vm.vehicle != null)
                        SecondaryButton(
                          label: 'Download payoff receipt',
                          icon: Icons.download_outlined,
                          onPressed: () =>
                              context.read<PdfService>().payoffReceipt(
                                    sale: sale,
                                    customer: vm.customer!,
                                    vehicle: vm.vehicle!,
                                  ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    */

                    // ── Payment history + Reminders / Collections ────────────
                    if (sale.mode == PaymentMode.installments) ...[
                      // Payment history — all payments (manual + installment).
                      AppCard(
                        onTap: () => _paymentHistory(context, vm),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, color: c.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text('Payment history',
                                  style: AppTextStyles.bodyStrong
                                      .copyWith(color: c.textMain)),
                            ),
                            Text('${sale.payments.length}',
                                style: AppTextStyles.body
                                    .copyWith(color: c.textSub)),
                            Icon(Icons.chevron_right, color: c.textSub),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Reminders',
                          style: AppTextStyles.pageTitle
                              .copyWith(color: c.textMain)),
                      if (vm.canModify && !vm.isClosed) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: vm.busy
                                    ? null
                                    : () => _manualPay(context, vm),
                                icon: const Icon(Icons.payments_outlined,
                                    size: 18),
                                label: const Text('Manual pay'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: vm.busy
                                    ? null
                                    : () => _setReminder(context, vm),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Set reminder'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      if (sale.installments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(
                            'No reminders yet. Tap "Set reminder" to schedule a collection.',
                            style:
                                AppTextStyles.body.copyWith(color: c.textSub),
                          ),
                        )
                      else
                        for (final inst in sale.installments) ...[
                          _reminderTile(context, vm, sale, inst, c),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      const SizedBox(height: AppSpacing.lg),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label,
      required this.value,
      required this.c,
      this.highlight = false});
  final String label;
  final String value;
  final AppColors c;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                color: highlight ? c.danger : c.textMain,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner shown when an admin has requested a seize that awaits a super admin.
/// The super admin sees Approve / Reject; others see an info note.
class _SeizeApprovalBanner extends StatelessWidget {
  const _SeizeApprovalBanner({
    required this.reason,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  final String? reason;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: c.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Seize requested — awaiting approval',
                    style:
                        AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reason: $reason',
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
          ],
          if (canReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Generic pending-approval banner (icon + title + reason + Approve/Reject).
/// Used for the pending unsell request.
class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({
    required this.icon,
    required this.title,
    required this.reason,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  final IconData icon;
  final String title;
  final String? reason;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style:
                        AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reason: $reason',
                style: AppTextStyles.caption.copyWith(color: c.textSub)),
          ],
          if (canReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the balance is cleared but the sale isn't yet confirmed sold.
class _ConfirmSoldBanner extends StatelessWidget {
  const _ConfirmSoldBanner({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: c.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Balance fully paid',
                    style:
                        AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Confirm this sale as sold to finish it.',
              style: AppTextStyles.caption.copyWith(color: c.textSub)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.sell_outlined, size: 18),
              label: const Text('Confirm sold'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A picked payment-proof screenshot held in memory before upload.
class _PickedShot {
  _PickedShot(this.name, this.bytes, this.mime);
  final String name;
  final Uint8List bytes;
  final String? mime;
}

/// One row in the payment-history sheet: amount, kind, date, status + proof.
/// A super admin sees Approve / Decline on a still-pending payment.
class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow(
      {required this.payment,
      required this.onView,
      required this.c,
      this.onApprove,
      this.onDecline});
  final SalePayment payment;
  final void Function(int docId) onView;
  final AppColors c;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = payment.isApproved
        ? ('Approved', c.success)
        : payment.isRejected
            ? ('Rejected', c.danger)
            : ('Pending', c.warning);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(Formatters.currency(payment.amount),
                        style: AppTextStyles.bodyStrong
                            .copyWith(color: c.textMain)),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                          style: AppTextStyles.caption
                              .copyWith(color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    payment.isManual ? 'Manual' : 'Installment',
                    if (payment.paidAt != null) Formatters.date(payment.paidAt!),
                  ].join('  ·  '),
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                ),
                if (payment.isRejected &&
                    (payment.rejectionReason?.isNotEmpty ?? false))
                  Text('Reason: ${payment.rejectionReason}',
                      style: AppTextStyles.caption.copyWith(color: c.danger)),
                if (onApprove != null || onDecline != null)
                  Row(
                    children: [
                      if (onApprove != null)
                        TextButton(
                            onPressed: onApprove,
                            child: const Text('Approve')),
                      if (onDecline != null)
                        TextButton(
                            onPressed: onDecline,
                            child: const Text('Decline')),
                    ],
                  ),
              ],
            ),
          ),
          if (payment.documentIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              tooltip: 'View screenshot',
              onPressed: () => onView(payment.documentIds.first),
            ),
        ],
      ),
    );
  }
}
