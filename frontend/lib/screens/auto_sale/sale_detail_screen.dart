import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/installment.dart';
import '../../models/reminder_log.dart';
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

  Future<void> _onMarkPaid(
      BuildContext context, SaleDetailViewModel vm, Installment inst) async {
    if (inst.isPaid || !vm.canModify) return;
    try {
      await vm.markPaid(inst.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Month ${inst.monthNumber} marked paid.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
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

                    // ── Installment history ─────────────────────────────────
                    if (sale.installments.isNotEmpty) ...[
                      Text('Installments',
                          style: AppTextStyles.pageTitle
                              .copyWith(color: c.textMain)),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < sale.installments.length;
                                i++) ...[
                              _InstallmentRow(
                                inst: sale.installments[i],
                                now: DateTime.now(),
                                canPay: vm.canModify && !vm.isClosed,
                                paying: vm.paying,
                                onPay: () => _onMarkPaid(
                                    context, vm, sale.installments[i]),
                                onReceipt: vm.customer != null &&
                                        vm.vehicle != null &&
                                        sale.installments[i].isPaid
                                    ? () => context
                                        .read<PdfService>()
                                        .installmentReceipt(
                                          sale: sale,
                                          customer: vm.customer!,
                                          vehicle: vm.vehicle!,
                                          installment: sale.installments[i],
                                        )
                                    : null,
                              ),
                              if (i != sale.installments.length - 1)
                                Divider(height: 1, color: c.borderColor),
                            ],
                          ],
                        ),
                      ),
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

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.inst,
    required this.now,
    required this.canPay,
    required this.paying,
    required this.onPay,
    this.onReceipt,
  });

  final Installment inst;
  final DateTime now;
  final bool canPay;
  final bool paying;
  final VoidCallback onPay;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = inst.statusAt(now);
    return InkWell(
      onTap: inst.isPaid || !canPay || paying ? null : onPay,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Month ${inst.monthNumber}  ·  ${Formatters.currency(inst.amount)}',
                    style: AppTextStyles.body.copyWith(color: c.textMain),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due ${Formatters.date(inst.dueDate)}'
                    '${inst.paidDate != null ? '  ·  Paid ${Formatters.date(inst.paidDate!)}' : ''}',
                    style: AppTextStyles.caption.copyWith(color: c.textSub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (inst.isPaid) ...[
              if (onReceipt != null)
                IconButton(
                  tooltip: 'Download receipt',
                  icon: Icon(Icons.download_outlined,
                      size: 18, color: c.textSub),
                  onPressed: onReceipt,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              Icon(Icons.check_circle, color: c.success, size: 20),
            ] else if (canPay && !paying)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: c.primary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Mark paid',
                    style: AppTextStyles.caption.copyWith(
                        color: c.primary, fontWeight: FontWeight.w600)),
              )
            else
              StatusPill.forSchedule(status),
          ],
        ),
      ),
    );
  }
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
