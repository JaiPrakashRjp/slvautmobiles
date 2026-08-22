import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../models/vehicle.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gold_create_button.dart';
import '../../widgets/icon_button_soft.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tab_bar_navy.dart';
import 'loan_vehicle_detail_screen.dart';
import 'loan_vehicle_form_screen.dart';
import 'new_loan_screen.dart';

/// Loan-module vehicles — the vehicle a loan is booked against. Same `vehicles`
/// table, scoped to module = loan, with photo + Insurance/FC/Permit and the
/// admin → super-admin approval flow.
class LoanVehiclesScreen extends StatefulWidget {
  const LoanVehiclesScreen({super.key});

  @override
  State<LoanVehiclesScreen> createState() => _LoanVehiclesScreenState();
}

class _LoanVehiclesScreenState extends State<LoanVehiclesScreen> {
  String _query = '';
  int _tab = 0; // 0 = On loan, 1 = Seized, 2 = Available
  static const _tabs = ['On loan', 'Seized', 'Available'];
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoanVehicleFormScreen()),
    );
  }

  List<Vehicle> _bucketList(LoanVehicleService service, Set<String> onLoan,
      Set<String> seized, int bucket) {
    final q = _query.trim().toLowerCase();
    return service.all().where((v) {
      // On loan takes precedence over a past seizure (re-loaned vehicle).
      final b = onLoan.contains(v.id)
          ? 0
          : seized.contains(v.id)
              ? 1
              : 2;
      if (b != bucket) return false;
      if (q.isEmpty) return true;
      return v.regNo.toLowerCase().contains(q) ||
          (v.model ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Widget _tabPage(BuildContext context, LoanVehicleService service,
      Set<String> onLoan, Set<String> seized, int bucket) {
    final list = _bucketList(service, onLoan, seized, bucket);
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
                icon: Icons.electric_rickshaw,
                title: 'No ${_tabs[bucket].toLowerCase()} vehicles',
                subtitle: 'Tap “+” to add a vehicle.',
                ctaLabel: 'Add vehicle',
                onCta: () => _openCreate(context),
              ),
            )
          else
            for (final v in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _LoanVehicleCard(
                  vehicle: v,
                  canAssign: v.isActive && !onLoan.contains(v.id),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final service = context.watch<LoanVehicleService>();
    final loans = context.watch<LoanService>();
    // A vehicle is "on loan" if it has a live (non-seized, non-rejected) loan;
    // "seized" if its loan was seized (repossessed, awaiting re-loan).
    final onLoan = <String>{
      for (final l in loans.all())
        if (l.vehicleId != null && !l.isSeized && l.loanStatus != 'rejected')
          l.vehicleId!,
    };
    final seized = <String>{
      for (final l in loans.all())
        if (l.vehicleId != null && l.isSeized) l.vehicleId!,
    };

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Loan vehicles'),
        actions: [
          GoldCreateButton(
            iconOnly: true,
            onPressed: () => _openCreate(context),
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
                    hintText: 'Search vehicle number / model…',
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
                      _tabPage(context, service, onLoan, seized, bucket),
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

class _LoanVehicleCard extends StatelessWidget {
  const _LoanVehicleCard({required this.vehicle, this.canAssign = false});

  final Vehicle vehicle;

  /// True when this vehicle can be loaned (active + not already on a live loan).
  final bool canAssign;

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoanVehicleDetailScreen(vehicleId: vehicle.id),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, LoanVehicleService service) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Delete vehicle',
      message:
          'Remove ${vehicle.displayLabel}? This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (ok == true) service.delete(vehicle.id);
  }

  /// Tap the photo → enlarged, zoomable image in a dialog with a Share button.
  void _showPhoto(
      BuildContext context, LoanVehicleService vehicles, DocRef ref) {
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
                    imageUrl: vehicles.documentUrl(ref.id),
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
                  onPressed: () => _sharePhoto(vehicles, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePhoto(LoanVehicleService vehicles, DocRef ref) async {
    final bytes = await vehicles.documentBytes(ref.id);
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
      subject: '${vehicle.displayLabel} — photo',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final service = context.read<LoanVehicleService>();
    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;
    // No delete once the vehicle has any loan (current or past history).
    final hasLoans = context
        .read<LoanService>()
        .all()
        .any((l) => l.vehicleId == vehicle.id);
    final photoRef = vehicle.uploadedDocs
        .where((d) => d.docTypeWire == 'photo')
        .cast<DocRef?>()
        .firstOrNull;

    return AppCard(
      onTap: () => _open(context),
      accentLeft: vehicle.isRejected,
      accentColor: vehicle.isRejected ? c.danger : null,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: photoRef == null
                        ? Container(
                            color: c.bgSurface,
                            child: Icon(Icons.electric_rickshaw,
                                color: c.textSub),
                          )
                        : CachedNetworkImage(
                            imageUrl: service.documentUrl(photoRef.id),
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: c.bgSurface),
                            errorWidget: (_, __, ___) => Container(
                              color: c.bgSurface,
                              child: Icon(Icons.electric_rickshaw,
                                  color: c.textSub),
                            ),
                          ),
                  ),
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
                        Text(vehicle.displayLabel,
                            style:
                                AppTextStyles.h2.copyWith(color: c.textMain)),
                        StatusPill.forEntity(vehicle.status),
                      ],
                    ),
                    if (vehicle.model != null && vehicle.model!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(vehicle.model!,
                          style:
                              AppTextStyles.caption.copyWith(color: c.textSub)),
                    ],
                    if (vehicle.isRejected &&
                        (vehicle.rejectionReason?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Rejected: ${vehicle.rejectionReason}',
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
          Row(
            children: [
              if (canAssign)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              NewLoanScreen(vehicleId: vehicle.id),
                        ),
                      ),
                      icon: const Icon(Icons.request_quote_outlined, size: 18),
                      label: const Text('Assign loan'),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (canModify) ...[
                IconButtonSoft(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  compact: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoanVehicleFormScreen(existing: vehicle),
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
            ],
          ),
        ],
      ),
    );
  }
}
