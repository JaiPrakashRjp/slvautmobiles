import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/loan.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'loan_customers_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_report_screen.dart';
import 'loan_vehicles_screen.dart';
import 'new_loan_screen.dart';

/// Loan list — spec 8.7.2.
class LoanHomeScreen extends StatefulWidget {
  const LoanHomeScreen({super.key});

  @override
  State<LoanHomeScreen> createState() => _LoanHomeScreenState();
}

class _LoanHomeScreenState extends State<LoanHomeScreen> {
  int _tab = 0;
  static const _filters = ['All', 'Active', 'Overdue', 'Closed'];
  static final DateTime _now = DateTime(2026, 6, 2);

  bool _matches(Loan l) {
    switch (_tab) {
      case 1:
        return l.loanStatus == 'active';
      case 2:
        return l.loanStatus == 'overdue';
      case 3:
        return l.isClosed;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loans = context.watch<LoanService>();
    final customers = context.watch<LoanCustomerService>();
    final list = loans.all().where(_matches).toList();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Loan customers',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanCustomersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.two_wheeler_outlined),
            tooltip: 'Loan vehicles',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanVehiclesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Loan report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanReportScreen()),
            ),
          ),
          GoldCreateButton(
            label: 'New loan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewLoanScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.lg, context.screenHPadding, AppSpacing.md),
                child: TabBarNavy(
                  tabs: _filters,
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No loans here',
                        subtitle: 'Tap “New loan” to disburse one.',
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                            context.screenHPadding, AppSpacing.xl),
                        children: [
                          for (final l in list)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _LoanCard(
                                loan: l,
                                name: customers.byId(l.customerId)?.fullName ??
                                    'Unknown',
                                now: _now,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.name, required this.now});

  final Loan loan;
  final String name;
  final DateTime now;

  PillVariant get _variant => switch (loan.loanStatus) {
        'overdue' => PillVariant.danger,
        'closed' || 'foreclosed' => PillVariant.success,
        'rejected' => PillVariant.danger,
        _ => PillVariant.info,
      };

  String get _statusLabel => switch (loan.loanStatus) {
        'active' => 'Active',
        'overdue' => 'Overdue',
        'closed' => 'Closed',
        'foreclosed' => 'Foreclosed',
        'rejected' => 'Rejected',
        _ => loan.loanStatus,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nextEmi = loan.nextDueEmi(now);
    return AppCard(
      accentLeft: loan.loanStatus == 'overdue',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: AppTextStyles.h2.copyWith(color: c.textMain)),
              ),
              StatusPill(label: _statusLabel, variant: _variant),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Principal ${Formatters.currency(loan.principal)} · EMI ${Formatters.currency(loan.emiAmount)}',
            style: AppTextStyles.body.copyWith(color: c.textSub),
          ),
          const SizedBox(height: 2),
          Text(
            'Outstanding ${Formatters.currency(loan.balanceOutstanding)}'
            '${nextEmi != null ? ' · Next due ${Formatters.date(nextEmi.dueDate)}' : ''}',
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
          if (loan.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            const StatusPill(label: 'Pending approval', variant: PillVariant.warning),
          ],
        ],
      ),
    );
  }
}
