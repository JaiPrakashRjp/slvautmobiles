import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoanVehicleFormScreen()),
    );
  }

  List<Vehicle> _filtered(
      LoanVehicleService service, Set<String> onLoan, Set<String> seized) {
    final q = _query.trim().toLowerCase();
    return service.all().where((v) {
      // On loan takes precedence over a past seizure (re-loaned vehicle).
      final bucket = onLoan.contains(v.id)
          ? 0
          : seized.contains(v.id)
              ? 1
              : 2;
      if (bucket != _tab) return false;
      if (q.isEmpty) return true;
      return v.regNo.toLowerCase().contains(q) ||
          (v.model ?? '').toLowerCase().contains(q);
    }).toList();
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
    final list = _filtered(service, onLoan, seized);

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
                  onChanged: (i) => setState(() => _tab = i),
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
                child: RefreshIndicator(
                  onRefresh: () => service.refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(context.screenHPadding, 0,
                        context.screenHPadding, AppSpacing.xl),
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
                            icon: Icons.two_wheeler_outlined,
                            title: 'No loan vehicles yet',
                            subtitle: 'Tap “+” to add a vehicle.',
                            ctaLabel: 'Add vehicle',
                            onCta: () => _openCreate(context),
                          ),
                        )
                      else
                        for (final v in list)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: _LoanVehicleCard(vehicle: v),
                          ),
                    ],
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

class _LoanVehicleCard extends StatelessWidget {
  const _LoanVehicleCard({required this.vehicle});

  final Vehicle vehicle;

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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.read<AuthController>();
    final service = context.read<LoanVehicleService>();
    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: photoRef == null
                      ? Container(
                          color: c.bgSurface,
                          child: Icon(Icons.two_wheeler_outlined,
                              color: c.textSub),
                        )
                      : CachedNetworkImage(
                          imageUrl: service.documentUrl(photoRef.id),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: c.bgSurface),
                          errorWidget: (_, __, ___) => Container(
                            color: c.bgSurface,
                            child: Icon(Icons.two_wheeler_outlined,
                                color: c.textSub),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonSoft(
                icon: Icons.visibility_outlined,
                tooltip: 'View vehicle',
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
                      builder: (_) => LoanVehicleFormScreen(existing: vehicle),
                    ),
                  ),
                ),
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
      ),
    );
  }
}
