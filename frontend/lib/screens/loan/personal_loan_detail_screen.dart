import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/personal_loan.dart';
import '../../models/personal_loan_emi.dart';
import '../../models/personal_loan_report.dart';
import '../../services/pdf_service.dart';
import '../../services/personal_loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/status_pill.dart';
import '../pdf_preview_screen.dart';

/// Personal loan detail — the loan summary + its monthly EMI list, where each
/// unpaid month has a ✓ button that (after a confirm) marks it paid.
class PersonalLoanDetailScreen extends StatelessWidget {
  const PersonalLoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = context.watch<PersonalLoanService>();
    final loan = service.byId(loanId);

    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal loan')),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final pdf = context.read<PdfService>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Personal loan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Loan report',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                title: 'Personal loan report',
                fileName:
                    'personal-loan-${loan.vehicleNumber.replaceAll(' ', '-')}.pdf',
                builder: () => pdf.personalLoanReportBytes(_report(loan)),
              ),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(loan.vehicleNumber,
                              style:
                                  AppTextStyles.h2.copyWith(color: c.textMain)),
                        ),
                        StatusPill(
                          label: loan.isClosed ? 'Paid' : 'Active',
                          variant: loan.isClosed
                              ? PillVariant.success
                              : PillVariant.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _row(c, 'Financer', loan.financerName ?? '—'),
                    _row(c, 'Loan amount',
                        Formatters.currency(loan.loanAmount)),
                    _row(c, 'EMI',
                        '${Formatters.currency(loan.emiAmount)} × ${loan.tenureMonths} mo'),
                    _row(c, 'Loan date', Formatters.date(loan.loanDate)),
                    if (loan.phone != null && loan.phone!.isNotEmpty)
                      _row(c, 'Reminder phone', Formatters.phone(loan.phone!)),
                    _row(c, 'Paid',
                        '${loan.paidCount}/${loan.tenureMonths} · ${Formatters.currency(loan.totalPaid)}'),
                    _row(c, 'Outstanding',
                        Formatters.currency(loan.outstanding)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text('EMI schedule',
                        style: AppTextStyles.pageTitle
                            .copyWith(color: c.textMain)),
                  ),
                  Text('${loan.paidCount}/${loan.tenureMonths} paid',
                      style: AppTextStyles.caption.copyWith(color: c.textSub)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < loan.emis.length; i++) ...[
                      _EmiRow(
                        emi: loan.emis[i],
                        onPay: () => _confirmPay(context, service, loan.emis[i]),
                      ),
                      if (i != loan.emis.length - 1)
                        Divider(height: 1, color: c.borderColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  PersonalLoanReport _report(PersonalLoan loan) => PersonalLoanReport(
        vehicleNumber: loan.vehicleNumber,
        financerName: loan.financerName ?? '',
        loanAmount: loan.loanAmount,
        emiAmount: loan.emiAmount,
        tenureMonths: loan.tenureMonths,
        loanDate: loan.loanDate,
        paid: loan.totalPaid,
        outstanding: loan.outstanding,
        status: loan.isClosed ? 'Paid' : 'Active',
        emis: [
          for (final e in loan.emis)
            PersonalLoanReportEmi(
              seq: e.sequenceNumber,
              dueDate: e.dueDate,
              amount: e.amount,
              paid: e.isPaid,
              paidDate: e.paidDate,
            ),
        ],
      );

  Future<void> _confirmPay(BuildContext context, PersonalLoanService service,
      PersonalLoanEmi emi) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Confirm payment',
      message:
          'Mark EMI ${emi.sequenceNumber} (${Formatters.currency(emi.amount)}) as paid?',
      confirmLabel: 'Confirm',
    );
    if (ok == true) {
      service.markEmiPaid(loanId, emi.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EMI ${emi.sequenceNumber} marked paid.')),
        );
      }
    }
  }

  Widget _row(AppColors c, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: AppTextStyles.caption.copyWith(color: c.textSub)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(value,
                  style: AppTextStyles.body.copyWith(color: c.textMain)),
            ),
          ],
        ),
      );
}

class _EmiRow extends StatelessWidget {
  const _EmiRow({required this.emi, required this.onPay});

  final PersonalLoanEmi emi;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMI ${emi.sequenceNumber} · ${Formatters.currency(emi.amount)}',
                    style: AppTextStyles.body.copyWith(color: c.textMain)),
                const SizedBox(height: 2),
                Text(
                  emi.isPaid && emi.paidDate != null
                      ? 'Due ${Formatters.date(emi.dueDate)} · paid ${Formatters.date(emi.paidDate!)}'
                      : 'Due ${Formatters.date(emi.dueDate)}',
                  style: AppTextStyles.caption.copyWith(color: c.textSub),
                ),
              ],
            ),
          ),
          if (emi.isPaid)
            Icon(Icons.check_circle, color: c.success, size: 24)
          else
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: c.primary),
              tooltip: 'Mark paid',
              onPressed: onPay,
            ),
        ],
      ),
    );
  }
}
