import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../models/customer.dart';
import '../../models/doc_ref.dart';
import '../../services/customer_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../viewmodels/customers_list_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/call_chip.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/page_size_picker.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'create_customer_screen.dart';
import 'customer_detail_screen.dart';

/// Customers list — mockup 07.
class CustomersListScreen extends StatelessWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomersListViewModel(
        context.read<CustomerService>(),
        context.read<VehicleService>(),
        context.read<AuthController>(),
        context.read<SaleService>(),
      ),
      child: const _CustomersListView(),
    );
  }
}

class _CustomersListView extends StatelessWidget {
  const _CustomersListView();

  Future<void> _openCreate(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateCustomerScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final customers = context.watch<CustomerService>();
    context.watch<VehicleService>();
    // Rebuild cards when sales change so the delete button hides/shows correctly.
    context.watch<SaleService>();
    final vm = context.watch<CustomersListViewModel>();

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Auto sale system'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to modules',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          GoldCreateButton(iconOnly: true, onPressed: () => _openCreate(context)),
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
                    AppSpacing.lg, context.screenHPadding, AppSpacing.md),
                child: TabBarNavy(
                  tabs: const ['With vehicle', 'Without vehicle'],
                  index: vm.tab,
                  onChanged: (i) => vm.tab = i,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                    context.screenHPadding, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (q) {
                          final t = q.trim();
                          vm.search(t.length >= 4 ? t : '');
                        },
                        decoration: InputDecoration(
                          hintText: 'Search name / phone…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PageSizePicker(
                        value: vm.pageSize, onChanged: (v) => vm.pageSize = v),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final vel = d.primaryVelocity ?? 0;
                    if (vel < -250 && vm.tab == 0) vm.tab = 1;
                    if (vel > 250 && vm.tab == 1) vm.tab = 0;
                  },
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final vehicleSvc = context.read<VehicleService>();
                      await customers.refresh();
                      await vehicleSvc.refresh();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                          context.screenHPadding, AppSpacing.xl),
                      children: [
                        if (customers.loading && vm.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (vm.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyState(
                              icon: Icons.people_outline,
                              title: vm.tab == 0
                                  ? 'No customers with a vehicle'
                                  : 'No customers without a vehicle',
                              subtitle: 'Tap “+” to add a customer.',
                              ctaLabel: 'Add customer',
                              onCta: () => _openCreate(context),
                            ),
                          )
                        else ...[
                          for (final cust in vm.pageItems)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: _CustomerCard(customer: cust, vm: vm),
                            ),
                          if (vm.totalPages > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: vm.page > 0
                                      ? () => vm.setPage(vm.page - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('Page ${vm.page + 1} of ${vm.totalPages}'),
                                IconButton(
                                  onPressed: vm.page < vm.totalPages - 1
                                      ? () => vm.setPage(vm.page + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.vm});

  final Customer customer;
  final CustomersListViewModel vm;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete customer',
      message: 'Remove ${customer.fullName}? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) vm.delete(customer.id);
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(customerId: customer.id),
    ));
  }

  /// Tap the avatar → enlarged, zoomable photo in a dialog with a Share button.
  /// Tap the image (or outside) to close.
  void _showPhoto(BuildContext context, CustomerService customers, DocRef ref) {
    final url = customers.documentUrl(ref.id);
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
                    imageUrl: url,
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

  /// Fetch the photo bytes and hand them to the OS share sheet.
  Future<void> _sharePhoto(CustomerService customers, DocRef ref) async {
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
    final customers = context.read<CustomerService>();
    final canModify =
        auth.isSuperAdmin || customer.createdBy == auth.currentUser?.id;
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
          // ── Top: photo + details + status (full width) ────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo (tap to enlarge)
              GestureDetector(
                onTap: photoRef == null
                    ? null
                    : () => _showPhoto(context, customers, photoRef),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: c.bgSurface,
                  backgroundImage: photoRef == null
                      ? null
                      // Disk-cached: downloads once, then loads instantly.
                      : CachedNetworkImageProvider(
                          customers.documentUrl(photoRef.id)),
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
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: c.borderColor),
          const SizedBox(height: AppSpacing.sm),
          // ── Below: small action icons, right-aligned ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View customer',
                compact: true,
                onPressed: () => _open(context),
              ),
              if (canModify) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButtonSoft(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  compact: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateCustomerScreen(existing: customer),
                    ),
                  ),
                ),
                // Delete only for a customer with no sales — one tied to a sale
                // keeps that record, so no delete.
                if (!vm.hasSale(customer.id)) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButtonSoft(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    danger: true,
                    compact: true,
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}
