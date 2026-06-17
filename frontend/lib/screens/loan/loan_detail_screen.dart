import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/emi.dart';
import '../../models/loan.dart';
import '../../services/customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';

/// Loan detail — spec 8.7.4.
class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  static final DateTime _now = DateTime(2026, 6, 2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loans = context.watch<LoanService>();
    final customers = context.read<CustomerService>();
    final auth = context.read<AuthController>();
    final loan = loans.byId(loanId);

    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final customer = customers.byId(loan.customerId);
    final name = customer?.fullName ?? 'Unknown';
    final nextEmi = loan.nextDueEmi(_now);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan detail'),
        actions: [
          if (auth.isSuperAdmin && !loan.isClosed && loan.isActive)
            IconButton(
              icon: const Icon(Icons.description_outlined),
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
                          label: loan.loanStatus,
                          variant: loan.loanStatus == 'overdue'
                              ? PillVariant.danger
                              : loan.isClosed
                                  ? PillVariant.success
                                  : PillVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Principal ${Formatters.currency(loan.principal)} · ${loan.rate}% · ${loan.tenureMonths} mo',
                      style: AppTextStyles.body.copyWith(color: c.textSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _stat(context, 'Paid', Formatters.currency(loan.totalPaid)),
                  const SizedBox(width: AppSpacing.md),
                  _stat(context, 'Outstanding',
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
                    'Penalty accrued: ${Formatters.currency(loan.penaltyAccrued)}',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.danger),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('EMI schedule',
                  style: AppTextStyles.pageTitle.copyWith(color: c.textMain)),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < loan.emis.length; i++) ...[
                      _EmiRow(
                        emi: loan.emis[i],
                        now: _now,
                        canPay: loan.isActive && !loan.emis[i].isPaid,
                        canWaive: auth.isSuperAdmin && loan.emis[i].penalty > 0,
                        onPay: () => _recordPayment(context, loans, loan, loan.emis[i]),
                        onWaive: () =>
                            loans.waivePenalty(loan.id, loan.emis[i].id),
                      ),
                      if (i != loan.emis.length - 1)
                        Divider(height: 1, color: c.borderColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              RoleGateActions(
                status: loan.status,
                onApprove: () => loans.confirm(
                    loan.id, auth.currentUser?.id ?? 'u_super'),
                onReject: (reason) => loans.reject(
                    loan.id, reason, auth.currentUser?.id ?? 'u_super'),
              ),
              if (loan.isClosed) ...[
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'View NOC',
                  icon: Icons.verified_outlined,
                  onPressed: customer == null
                      ? null
                      : () => context
                          .read<PdfService>()
                          .previewNoc(loan: loan, customer: customer),
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
            Text(value, style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(
      BuildContext context, LoanService loans, Loan loan, Emi emi) async {
    final controller =
        TextEditingController(text: (emi.remaining + emi.penalty).toString());
    final c = context.colors;
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgContainer,
        title: Text('Record EMI ${emi.sequenceNumber} payment',
            style: AppTextStyles.h2.copyWith(color: c.textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Allocated to penalty first, then the EMI.',
              style: AppTextStyles.caption.copyWith(color: c.textSub),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Amount',
              prefixText: '₹ ',
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      loans.recordEmiPayment(loan.id, emi.id, amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorded ${Formatters.currency(amount)}.')),
        );
      }
    }
  }

  Future<void> _foreclose(
      BuildContext context, LoanService loans, Loan loan) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Foreclose loan',
      message:
          'Settle the full outstanding of ${Formatters.currency(loan.balanceOutstanding)} and close the loan? An NOC will be issued.',
      confirmLabel: 'Foreclose',
    );
    if (ok == true) {
      loans.foreclose(loan.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan foreclosed. NOC issued.')),
        );
      }
    }
  }
}

class _EmiRow extends StatelessWidget {
  const _EmiRow({
    required this.emi,
    required this.now,
    required this.canPay,
    required this.canWaive,
    required this.onPay,
    required this.onWaive,
  });

  final Emi emi;
  final DateTime now;
  final bool canPay;
  final bool canWaive;
  final VoidCallback onPay;
  final VoidCallback onWaive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = emi.statusAt(now);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMI ${emi.sequenceNumber} · ${Formatters.currency(emi.amountDue)}',
                    style: AppTextStyles.body.copyWith(color: c.textMain)),
                const SizedBox(height: 2),
                Text(
                  Formatters.date(emi.dueDate) +
                      (emi.penalty > 0
                          ? ' · penalty ${Formatters.currency(emi.penalty)}'
                          : ''),
                  style: AppTextStyles.caption.copyWith(
                      color: emi.penalty > 0 ? c.danger : c.textSub),
                ),
              ],
            ),
          ),
          if (emi.isPaid)
            Icon(Icons.check_circle, color: c.success, size: 20)
          else ...[
            StatusPill.forSchedule(status),
            if (canWaive) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onWaive, child: const Text('Waive')),
            ],
            if (canPay) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(Icons.payments_outlined, color: c.primary, size: 20),
                tooltip: 'Record payment',
                onPressed: onPay,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
