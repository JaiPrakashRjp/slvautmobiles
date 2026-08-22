import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/personal_loan.dart';
import '../../services/personal_loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/status_pill.dart';
import 'new_personal_loan_screen.dart';
import 'personal_loan_detail_screen.dart';

/// Personal loans list.
class PersonalLoanHomeScreen extends StatelessWidget {
  const PersonalLoanHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = context.watch<PersonalLoanService>();
    final list = service.all();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Personal loans'),
        actions: [
          GoldCreateButton(
            label: 'New loan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewPersonalLoanScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: RefreshIndicator(
            onRefresh: () => service.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(context.screenHPadding, AppSpacing.lg,
                  context.screenHPadding, AppSpacing.xl),
              children: [
                if (service.loading && list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No personal loans yet',
                      subtitle: 'Tap “New loan” to add one.',
                    ),
                  )
                else
                  for (final l in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _PersonalLoanCard(loan: l),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalLoanCard extends StatelessWidget {
  const _PersonalLoanCard({required this.loan});

  final PersonalLoan loan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = loan.nextDue();
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PersonalLoanDetailScreen(loanId: loan.id),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(loan.vehicleNumber,
                    style: AppTextStyles.h2.copyWith(color: c.textMain)),
              ),
              StatusPill(
                label: loan.isClosed ? 'Paid' : 'Active',
                variant:
                    loan.isClosed ? PillVariant.success : PillVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${loan.financerName ?? 'No financer'} · Loan ${Formatters.currency(loan.loanAmount)} · '
            'EMI ${Formatters.currency(loan.emiAmount)} · ${loan.tenureMonths} mo',
            style: AppTextStyles.body.copyWith(color: c.textSub),
          ),
          const SizedBox(height: 2),
          Text(
            'Paid ${loan.paidCount}/${loan.tenureMonths} · '
            'Outstanding ${Formatters.currency(loan.outstanding)}'
            '${next != null ? ' · Next due ${Formatters.date(next.dueDate)}' : ''}',
            style: AppTextStyles.caption.copyWith(color: c.textSub),
          ),
        ],
      ),
    );
  }
}
