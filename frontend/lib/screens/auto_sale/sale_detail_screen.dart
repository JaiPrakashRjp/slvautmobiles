import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/installment.dart';
import '../../models/reminder_log.dart';
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
import '../../widgets/primary_button.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/secondary_button.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleDetailViewModel>().loadReminders();
    });
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
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
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

  Future<void> _onPayOff(BuildContext context, SaleDetailViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pay off remaining'),
        content: const Text(
            'Mark all remaining installments as paid and close this sale?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pay off')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await vm.payOff();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale closed — all installments settled.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
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
                phone: ListView(
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
                                value: vm.vehicle!.regNo,
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
                          _SummaryRow(
                              label: 'Down payment',
                              value: Formatters.currency(sale.advance),
                              c: c),
                          // Down-payment / loan sale: show HP + typed remaining.
                          if (sale.mode == PaymentMode.installments) ...[
                            if (sale.hpAmount != null)
                              _SummaryRow(
                                  label: 'HP amount',
                                  value: Formatters.currency(sale.hpAmount!),
                                  c: c),
                            _SummaryRow(
                                label: 'Remaining',
                                value: Formatters.currency(sale.remainingAmount),
                                c: c,
                                highlight: sale.remainingAmount > 0),
                          ],
                          _SummaryRow(
                              label: 'Status',
                              value: sale.saleStatus,
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

                    // ── Pay off / payoff receipt ─────────────────────────────
                    if (sale.mode == PaymentMode.installments) ...[
                      if (vm.hasUnpaid && !vm.isClosed && vm.canModify)
                        PrimaryButton(
                          label: vm.payingOff ? 'Processing…' : 'Pay off remaining',
                          icon: Icons.payments_outlined,
                          onPressed:
                              vm.payingOff ? null : () => _onPayOff(context, vm),
                        ),
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

                    // ── Reminders / Collections ──────────────────────────────
                    if (sale.mode == PaymentMode.installments) ...[
                      Row(
                        children: [
                          Text('Reminders',
                              style: AppTextStyles.pageTitle
                                  .copyWith(color: c.textMain)),
                          const Spacer(),
                          if (vm.canModify && !vm.isClosed)
                            TextButton.icon(
                              onPressed: vm.busy
                                  ? null
                                  : () => _setReminder(context, vm),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Set reminder'),
                            ),
                        ],
                      ),
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

                    // ── Reminders sent (installments only) ─────────────────
                    if (sale.mode == PaymentMode.installments) ...[
                      Text('Reminders sent',
                          style: AppTextStyles.pageTitle
                              .copyWith(color: c.textMain)),
                      const SizedBox(height: AppSpacing.sm),
                      if (vm.loadingReminders)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (vm.reminders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: AppSpacing.sm, bottom: AppSpacing.lg),
                          child: Text('No reminders sent yet.',
                              style: AppTextStyles.body
                                  .copyWith(color: c.textSub)),
                        )
                      else
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < vm.reminders.length;
                                  i++) ...[
                                _ReminderRow(log: vm.reminders[i], c: c),
                                if (i != vm.reminders.length - 1)
                                  Divider(height: 1, color: c.borderColor),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      SecondaryButton(
                        label: 'Refresh reminders',
                        icon: Icons.refresh,
                        onPressed: () =>
                            context.read<SaleDetailViewModel>().loadReminders(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
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

/// A picked payment-proof screenshot held in memory before upload.
class _PickedShot {
  _PickedShot(this.name, this.bytes, this.mime);
  final String name;
  final Uint8List bytes;
  final String? mime;
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.log, required this.c});
  final ReminderLog log;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final label = log.recipientType == 'super_admin' ? 'Super admin' : 'Customer';
    final sentLabel = log.sentAt != null
        ? Formatters.dateTime(log.sentAt!)
        : log.status;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.send, size: 16, color: log.isSent ? c.success : c.textSub),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label  ·  ${log.recipientPhone}',
                  style: AppTextStyles.body.copyWith(color: c.textMain),
                ),
                Text(
                  'Due ${Formatters.date(log.dueDate)}  ·  $sentLabel',
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
