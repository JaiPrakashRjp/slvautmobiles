import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../models/customer.dart';
import '../../models/doc_ref.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import '../auto_sale/create_customer_screen.dart';
import 'loan_customer_detail_screen.dart';
import 'loan_report_screen.dart';

/// Loan-module customers — same tables/fields/approval flow as the sale
/// customers, scoped to module = loan, with the richer assurity document set.
class LoanCustomersScreen extends StatefulWidget {
  const LoanCustomersScreen({super.key});

  @override
  State<LoanCustomersScreen> createState() => _LoanCustomersScreenState();
}

class _LoanCustomersScreenState extends State<LoanCustomersScreen> {
  String _query = '';
  int _tab = 0; // 0 = All, 1 = Seized
  static const _tabs = ['All', 'Seized'];
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openCreate(BuildContext context, LoanCustomerService service) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateCustomerScreen(
          service: service,
          extendedAssurity: true,
        ),
      ),
    );
  }

  List<Customer> _bucketList(
      LoanCustomerService service, Set<String> seized, int bucket) {
    final q = _query.trim().toLowerCase();
    return service.all().where((c) {
      if (bucket == 1 && !seized.contains(c.id)) return false;
      if (q.isEmpty) return true;
      return c.fullName.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();
  }

  Widget _tabPage(BuildContext context, LoanCustomerService service,
      Set<String> seized, int bucket) {
    final list = _bucketList(service, seized, bucket);
    return RefreshIndicator(
      onRefresh: () => service.refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            context.screenHPadding, 0, context.screenHPadding, AppSpacing.xl),
        children: [
          if (service.loading && list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.people_outline,
                title: bucket == 1
                    ? 'No seized customers'
                    : 'No loan customers yet',
                subtitle: 'Tap “+” to add a customer.',
                ctaLabel: 'Add customer',
                onCta: () => _openCreate(context, service),
              ),
            )
          else
            for (final cust in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _LoanCustomerCard(customer: cust),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = context.watch<LoanCustomerService>();
    final loans = context.watch<LoanService>();
    // Customers whose loan vehicle was seized.
    final seized = <String>{
      for (final l in loans.all())
        if (l.isSeized) l.customerId,
    };

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Loan report',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoanReportScreen()),
            ),
          ),
          GoldCreateButton(
            iconOnly: true,
            onPressed: () => _openCreate(context, service),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          maxFormWidth: 720,
          phone: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    AppSpacing.lg, context.screenHPadding, AppSpacing.sm),
                child: TabBarNavy(
                  tabs: _tabs,
                  index: _tab,
                  onChanged: (i) => _pageCtrl.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding,
                    0, context.screenHPadding, AppSpacing.sm),
                child: TextField(
                  onChanged: (q) => setState(() => _query = q),
                  decoration: InputDecoration(
                    hintText: 'Search name / phone…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _tab = i),
                  children: [
                    for (var bucket = 0; bucket < _tabs.length; bucket++)
                      _tabPage(context, service, seized, bucket),
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

class _LoanCustomerCard extends StatelessWidget {
  const _LoanCustomerCard({required this.customer});

  final Customer customer;

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoanCustomerDetailScreen(customerId: customer.id),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, LoanCustomerService service) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete customer',
      message: 'Remove ${customer.fullName}? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) service.delete(customer.id);
  }

  /// Tap the avatar → enlarged, zoomable photo in a dialog with a Share button.
  void _showPhoto(
      BuildContext context, LoanCustomerService customers, DocRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: customers.documentUrl(ref.id),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 240,
                      child: Center(
                          child: Icon(Icons.broken_image_outlined, size: 48)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: 'Share photo',
                  onPressed: () => _sharePhoto(customers, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePhoto(LoanCustomerService customers, DocRef ref) async {
    final bytes = await customers.documentBytes(ref.id);
    if (bytes.isEmpty) return;
    final name = ref.fileName.isEmpty ? 'photo.jpg' : ref.fileName;
    final lower = name.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.heic')
            ? 'image/heic'
            : 'image/jpeg';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: name, mimeType: mime)],
      subject: '${customer.fullName} — photo',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final service = context.read<LoanCustomerService>();
    final canModify =
        auth.isSuperAdmin || customer.createdBy == auth.currentUser?.id;
    // No delete once the customer has any loan (active or history) — keeps the
    // records intact.
    final hasLoans =
        context.read<LoanService>().forCustomer(customer.id).isNotEmpty;
    final photoRef = customer.uploadedDocs
        .where((d) => d.docTypeWire == 'photo')
        .cast<DocRef?>()
        .firstOrNull;

    return AppCard(
      onTap: () => _open(context),
      accentLeft: customer.isRejected,
      accentColor: customer.isRejected ? c.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: photoRef == null
                    ? null
                    : () => _showPhoto(context, service, photoRef),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: c.bgSurface,
                  backgroundImage: photoRef == null
                      ? null
                      : CachedNetworkImageProvider(
                          service.documentUrl(photoRef.id)),
                  child: photoRef == null
                      ? Icon(Icons.person_outline, color: c.textSub)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        Text(customer.fullName,
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain)),
                        StatusPill.forEntity(customer.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CallChip(phone: customer.phone),
                    ),
                    if (customer.isRejected &&
                        (customer.rejectionReason?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Rejected: ${customer.rejectionReason}',
                          style:
                              AppTextStyles.caption.copyWith(color: c.danger)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canModify) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: c.borderColor),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButtonSoft(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  compact: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateCustomerScreen(
                        existing: customer,
                        service: service,
                        extendedAssurity: true,
                      ),
                    ),
                  ),
                ),
                if (!hasLoans) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButtonSoft(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    danger: true,
                    compact: true,
                    onPressed: () => _confirmDelete(context, service),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
