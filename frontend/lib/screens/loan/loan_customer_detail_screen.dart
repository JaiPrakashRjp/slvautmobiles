import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/status_pill.dart';
import '../auto_sale/create_customer_screen.dart';
import '../document_preview_screen.dart';
import 'loan_detail_screen.dart';

/// Loan-module customer detail — borrower + assurity (with photo & documents) +
/// approval flow, plus any loans booked against this customer.
class LoanCustomerDetailScreen extends StatelessWidget {
  const LoanCustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customers = context.watch<LoanCustomerService>();
    final loans = context.watch<LoanService>();
    final auth = context.read<AuthController>();

    final customer = customers.byId(customerId);
    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan customer')),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final canModify =
        auth.isSuperAdmin || customer.createdBy == auth.currentUser?.id;
    final borrowerDocs = customer.uploadedDocs
        .where((d) => !_isAssurity(d.docTypeWire) && d.docTypeWire != 'photo')
        .toList();
    final assurityDocs = customer.uploadedDocs
        .where((d) => _isAssurity(d.docTypeWire))
        .toList();
    final customerLoans = loans.forCustomer(customerId);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan customer'),
        actions: [
          if (canModify)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateCustomerScreen(
                    existing: customer,
                    service: customers,
                    extendedAssurity: true,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              if (!customer.isActive) ...[
                RoleGateBanner(
                  status: customer.status,
                  rejectionReason: customer.rejectionReason,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Borrower ────────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(customer.fullName,
                              style:
                                  AppTextStyles.h2.copyWith(color: c.textMain)),
                        ),
                        StatusPill.forEntity(customer.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _Row(label: 'Phone',
                        value: Formatters.phone(customer.phone), c: c),
                    if (customer.address.isNotEmpty)
                      _Row(label: 'Address', value: customer.address, c: c),
                    if (customer.branch != null)
                      _Row(label: 'Branch', value: customer.branch!.label, c: c),
                    if (customer.age != null)
                      _Row(label: 'Age', value: '${customer.age}', c: c),
                    if (customer.remarks != null &&
                        customer.remarks!.isNotEmpty)
                      _Row(label: 'Remarks', value: customer.remarks!, c: c),
                  ],
                ),
              ),

              // ── Borrower documents ──────────────────────────────────────
              if (borrowerDocs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Documents',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                _DocsCard(docs: borrowerDocs, customers: customers),
              ],

              // ── Assurity person ─────────────────────────────────────────
              if (customer.assurityName != null &&
                  customer.assurityName!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Assurity person',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: 'Name', value: customer.assurityName!, c: c),
                      if (customer.assurityMobile != null &&
                          customer.assurityMobile!.isNotEmpty)
                        _Row(
                            label: 'Mobile',
                            value: Formatters.phone(customer.assurityMobile!),
                            c: c),
                    ],
                  ),
                ),
                if (assurityDocs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _DocsCard(docs: assurityDocs, customers: customers),
                ],
              ],

              // ── Loans ───────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              Text('Loans',
                  style: AppTextStyles.label.copyWith(color: c.textSub)),
              const SizedBox(height: AppSpacing.sm),
              if (customerLoans.isEmpty)
                AppCard(
                  child: Text('No loans yet.',
                      style: AppTextStyles.body.copyWith(color: c.textSub)),
                )
              else
                for (final loan in customerLoans) ...[
                  AppCard(
                    accentLeft: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoanDetailScreen(loanId: loan.id),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Principal ${Formatters.currency(loan.principal)}',
                                style: AppTextStyles.bodyStrong
                                    .copyWith(color: c.textMain),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'EMI ${Formatters.currency(loan.emiAmount)} · '
                                'Outstanding ${Formatters.currency(loan.balanceOutstanding)}',
                                style: AppTextStyles.caption
                                    .copyWith(color: c.textSub),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: c.textSub),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

              // ── Approve / reject ────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              RoleGateActions(
                status: customer.status,
                onApprove: () {
                  customers.confirm(
                      customer.id, auth.currentUser?.id ?? 'u_super');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer approved.')),
                  );
                },
                onReject: (reason) {
                  customers.reject(
                      customer.id, reason, auth.currentUser?.id ?? 'u_super');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer rejected.')),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isAssurity(String wire) => wire.startsWith('assurity');

/// Friendly label for a KYC / assurity document's backend wire.
String _kycLabel(String wire) => switch (wire) {
      'aadhaar' => 'Aadhaar',
      'pan' => 'PAN',
      'dl' => 'Driving licence',
      'photo' => 'Photo',
      'rental_agreement' => 'Rental agreement',
      'assurity_id_proof' => 'Assurity ID proof',
      'assurity_aadhaar' => 'Assurity Aadhaar',
      'assurity_pan' => 'Assurity PAN',
      'assurity_photo' => 'Assurity photo',
      'assurity_other_1' => 'Assurity other 1',
      'assurity_other_2' => 'Assurity other 2',
      _ => wire.replaceAll('_', ' '),
    };

class _DocsCard extends StatelessWidget {
  const _DocsCard({required this.docs, required this.customers});

  final List<DocRef> docs;
  final LoanCustomerService customers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++) ...[
            ListTile(
              dense: true,
              leading: Icon(Icons.description_outlined, color: c.primary),
              title: Text(_kycLabel(docs[i].docTypeWire)),
              subtitle: Text(docs[i].fileName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.visibility_outlined),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentPreviewScreen(
                    title: _kycLabel(docs[i].docTypeWire),
                    fileName: docs[i].fileName,
                    loader: () => customers.documentBytes(docs[i].id),
                  ),
                ),
              ),
            ),
            if (i != docs.length - 1)
              Divider(height: 1, color: c.borderColor),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.c});
  final String label;
  final String value;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
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
}
