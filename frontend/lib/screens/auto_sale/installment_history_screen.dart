import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/enums.dart';
import '../../models/installment.dart';
import '../../services/customer_service.dart';
import '../../services/notification_service.dart';
import '../../services/pdf_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/installment_history_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';

/// Installment history — mockup 10. Open by sale id or by customer id.
class InstallmentHistoryScreen extends StatelessWidget {
  const InstallmentHistoryScreen({super.key, this.saleId, this.customerId})
      : assert(saleId != null || customerId != null);

  final String? saleId;
  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InstallmentHistoryViewModel(
        saleId: saleId,
        customerId: customerId,
        sales: context.read<SaleService>(),
        vehicles: context.read<VehicleService>(),
        customers: context.read<CustomerService>(),
        auth: context.read<AuthController>(),
      ),
      child: const _InstallmentHistoryView(),
    );
  }
}

class _InstallmentHistoryView extends StatelessWidget {
  const _InstallmentHistoryView();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<SaleService>();
    final vm = context.watch<InstallmentHistoryViewModel>();
    final sale = vm.sale;
    final now = DateTime(2026, 6, 2);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('User · Installments'),
        actions: [
          if (sale != null && vm.customer != null && vm.vehicle != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Invoice',
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
                child: Text('No installment sale found',
                    style: AppTextStyles.body.copyWith(color: c.textSub)),
              )
            : ResponsiveBody(
                maxFormWidth: 560,
                phone: ListView(
                  padding: EdgeInsets.all(context.screenHPadding),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User: ${vm.customer?.fullName ?? '—'}',
                              style: AppTextStyles.body
                                  .copyWith(color: c.textSub)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Assigned to ${vm.vehicle?.regNo ?? '—'}',
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Installments',
                        style:
                            AppTextStyles.pageTitle.copyWith(color: c.textMain)),
                    const SizedBox(height: 2),
                    Text('Reminder & sent',
                        style: AppTextStyles.body.copyWith(color: c.textSub)),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < sale.installments.length; i++) ...[
                            _InstallmentRow(
                              installment: sale.installments[i],
                              now: now,
                              canPay: vm.canRecordPayment,
                              onPay: () =>
                                  _onPay(context, vm, sale.installments[i]),
                            ),
                            if (i != sale.installments.length - 1)
                              Divider(height: 1, color: c.borderColor),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Builder(builder: (context) {
                      final due = sale.installments
                          .where((i) => !i.isPaid)
                          .toList()
                        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                      final phone = vm.customer?.phone ?? '';
                      if (due.isEmpty || phone.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final next = due.first;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: SecondaryButton(
                          label: 'Send WhatsApp reminder',
                          icon: Icons.send_outlined,
                          onPressed: () {
                            context.read<NotificationService>().paymentReminder(
                                  phone: phone,
                                  name: vm.customer?.fullName ?? '',
                                  amount: Formatters.currency(next.amount),
                                  dueDate: Formatters.date(next.dueDate),
                                  overdue:
                                      next.statusAt(now) == ScheduleStatus.overdue,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reminder sent.')),
                            );
                          },
                        ),
                      );
                    }),
                    Center(
                      child: Text('History of each installment',
                          style: AppTextStyles.caption
                              .copyWith(color: c.textSub)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _onPay(BuildContext context, InstallmentHistoryViewModel vm,
      Installment inst) {
    if (inst.isPaid || !vm.canRecordPayment) return;
    vm.markPaid(inst.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Month ${inst.monthNumber} marked paid.')),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.installment,
    required this.now,
    required this.canPay,
    required this.onPay,
  });

  final Installment installment;
  final DateTime now;
  final bool canPay;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = installment.statusAt(now);
    return InkWell(
      onTap: installment.isPaid || !canPay ? null : onPay,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Month ${installment.monthNumber} · ${Formatters.currency(installment.amount)}',
                style: AppTextStyles.body.copyWith(color: c.textMain),
              ),
            ),
            if (installment.isPaid)
              Icon(Icons.check, color: c.success, size: 20)
            else
              StatusPill.forSchedule(status),
          ],
        ),
      ),
    );
  }
}
