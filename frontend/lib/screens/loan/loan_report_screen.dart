import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../models/loan.dart';
import '../../models/loan_customer_report.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/picker_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';

/// Loan report — pick a loan customer, preview their full loan statement
/// (all loans + EMI schedules + totals) on screen, and download it as a PDF.
class LoanReportScreen extends StatefulWidget {
  const LoanReportScreen({super.key});

  @override
  State<LoanReportScreen> createState() => _LoanReportScreenState();
}

class _LoanReportScreenState extends State<LoanReportScreen> {
  String? _customerId;

  Future<void> _pickCustomer(
      BuildContext context, LoanCustomerService customers) async {
    final picked = await OptionSheet.show<String>(
      context,
      title: 'Select customer',
      selected: _customerId,
      options: customers
          .all()
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle: Formatters.phone(c.phone),
              ))
          .toList(),
    );
    if (picked != null) setState(() => _customerId = picked);
  }

  LoanCustomerReport _build(
      Customer cust, List<Loan> loans, LoanVehicleService vehicles) {
    final now = DateTime.now();
    final reportLoans = <LoanReportLoan>[];
    var totLoaned = 0, totPaid = 0, totOut = 0, totPen = 0;
    for (final l in loans) {
      final emis = [
        for (final e in l.emis)
          LoanReportEmi(
            seq: e.sequenceNumber,
            dueDate: e.dueDate,
            amount: e.amountDue,
            penalty: e.penalty,
            paid: e.amountPaid,
            balance: e.remaining,
            status: e.statusAt(now).label,
            receivedDate: e.receivedDate,
          ),
      ];
      totLoaned += l.principal;
      totPaid += l.totalPaid;
      totOut += l.balanceOutstanding;
      totPen += l.penaltyAccrued;
      reportLoans.add(LoanReportLoan(
        vehicleLabel:
            vehicles.byId(l.vehicleId ?? '')?.displayLabel ?? '—',
        principal: l.principal,
        emiAmount: l.emiAmount,
        tenureMonths: l.tenureMonths,
        loanDate: l.disbursementDate,
        status: _loanStatus(l),
        paid: l.totalPaid,
        outstanding: l.balanceOutstanding,
        penalty: l.penaltyAccrued,
        emis: emis,
      ));
    }
    return LoanCustomerReport(
      customerName: cust.fullName,
      phone: cust.phone,
      branch: cust.branch?.label ?? '',
      address: cust.address,
      assurityName: cust.assurityName,
      assurityMobile: cust.assurityMobile,
      totalLoaned: totLoaned,
      totalPaid: totPaid,
      totalOutstanding: totOut,
      totalPenalty: totPen,
      loans: reportLoans,
    );
  }

  static String _loanStatus(Loan l) => l.isSeized
      ? 'Seized'
      : l.isFullyPaid
          ? 'Paid'
          : l.loanStatus == 'overdue'
              ? 'Overdue'
              : l.isSeizePending
                  ? 'Seize pending'
                  : 'Active';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customers = context.watch<LoanCustomerService>();
    final loanSvc = context.watch<LoanService>();
    final vehicles = context.read<LoanVehicleService>();
    final pdf = context.read<PdfService>();

    final customer =
        _customerId == null ? null : customers.byId(_customerId!);
    final report = customer == null
        ? null
        : _build(customer, loanSvc.forCustomer(customer.id), vehicles);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('Loan report')),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 640,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              PickerField(
                label: 'Customer',
                required: true,
                leadingIcon: Icons.person_outline,
                placeholder: 'Select a customer',
                value: customer?.fullName,
                onTap: () => _pickCustomer(context, customers),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (report == null)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.assessment_outlined,
                    title: 'Pick a customer',
                    subtitle:
                        'Choose a customer to see their full loan statement.',
                  ),
                )
              else ...[
                _summaryCard(context, report),
                const SizedBox(height: AppSpacing.lg),
                if (report.loans.isEmpty)
                  AppCard(
                    child: Text('This customer has no loans.',
                        style: AppTextStyles.body.copyWith(color: c.textSub)),
                  )
                else
                  for (final l in report.loans) ...[
                    _loanCard(context, l),
                    const SizedBox(height: AppSpacing.md),
                  ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Preview PDF',
                        icon: Icons.visibility_outlined,
                        onPressed: report.loans.isEmpty
                            ? null
                            : () => pdf.previewLoanReport(report),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Download PDF',
                        icon: Icons.download_outlined,
                        onPressed: report.loans.isEmpty
                            ? null
                            : () => pdf.shareLoanReport(report),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, LoanCustomerReport r) {
    final c = context.colors;
    Widget tot(String k, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: AppTextStyles.caption.copyWith(color: c.textSub)),
            const SizedBox(height: 2),
            Text(v,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          ],
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.customerName,
              style: AppTextStyles.h2.copyWith(color: c.textMain)),
          const SizedBox(height: 2),
          Text(
            [
              if (r.phone.isNotEmpty) Formatters.phone(r.phone),
              if (r.branch.isNotEmpty) r.branch,
            ].join('  ·  '),
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              tot('Loans', '${r.loanCount}'),
              tot('Total loaned', Formatters.currency(r.totalLoaned)),
              tot('Total paid', Formatters.currency(r.totalPaid)),
              tot('Outstanding', Formatters.currency(r.totalOutstanding)),
              if (r.totalPenalty > 0)
                tot('Penalty', Formatters.currency(r.totalPenalty)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loanCard(BuildContext context, LoanReportLoan l) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('🛵 ${l.vehicleLabel}',
                    style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
              ),
              StatusPill(
                label: l.status,
                variant: l.status == 'Seized' || l.status == 'Overdue'
                    ? PillVariant.danger
                    : l.status == 'Paid'
                        ? PillVariant.success
                        : l.status == 'Seize pending'
                            ? PillVariant.warning
                            : PillVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Loan ${Formatters.currency(l.principal)} · EMI ${Formatters.currency(l.emiAmount)} · ${l.tenureMonths} mo · ${Formatters.date(l.loanDate)}',
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
          const SizedBox(height: 2),
          Text(
            'Paid ${Formatters.currency(l.paid)} · Outstanding ${Formatters.currency(l.outstanding)}'
            '${l.penalty > 0 ? ' · Penalty ${Formatters.currency(l.penalty)}' : ''}',
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
        ],
      ),
    );
  }
}
