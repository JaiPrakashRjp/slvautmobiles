import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../models/loan.dart';
import '../../models/picked_doc.dart';
import '../../models/vehicle.dart';
import '../../services/loan_customer_service.dart';
import '../../services/loan_service.dart';
import '../../services/loan_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/detail_field_card.dart';
import '../../widgets/doc_manager_tile.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_vehicle_form_screen.dart';

/// Loan-module vehicle detail — fields, photo, documents (view / upload /
/// delete), and the admin → super-admin approval actions.
class LoanVehicleDetailScreen extends StatefulWidget {
  const LoanVehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<LoanVehicleDetailScreen> createState() =>
      _LoanVehicleDetailScreenState();
}

class _LoanVehicleDetailScreenState extends State<LoanVehicleDetailScreen> {
  // The loan vehicle's document set: a photo + Insurance / FC / Permit.
  static const _docs = [
    ('photo', 'Photo'),
    ('insurance', 'Insurance'),
    ('fc', 'FC'),
    ('permit', 'Permit'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LoanVehicleService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vehicles = context.watch<LoanVehicleService>();
    final vehicle = vehicles.byId(widget.vehicleId);
    final auth = context.read<AuthController>();

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle detail')),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;
    final photoRef = vehicle.uploadedDocs
        .where((d) => d.docTypeWire == 'photo')
        .cast<DocRef?>()
        .firstOrNull;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Vehicle detail'),
        actions: [
          if (canModify)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit vehicle',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LoanVehicleFormScreen(existing: vehicle),
              )),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: RefreshIndicator(
            onRefresh: vehicles.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(context.screenHPadding),
              children: [
                if (!vehicle.isActive) ...[
                  RoleGateBanner(
                    status: vehicle.status,
                    rejectionReason: vehicle.rejectionReason,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (photoRef != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: vehicles.documentUrl(photoRef.id),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: c.bgSurface,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 180,
                        color: c.bgSurface,
                        child: Icon(Icons.two_wheeler_outlined,
                            size: 48, color: c.textSub),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ..._detailRows(vehicle),
                const SizedBox(height: AppSpacing.lg),
                Text('Documents',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                ..._docTiles(context, vehicles, vehicle),
                ..._loanHistory(context, vehicle),
                const SizedBox(height: AppSpacing.lg),
                RoleGateActions(
                  status: vehicle.status,
                  onApprove: () {
                    vehicles.confirm(
                        vehicle.id, auth.currentUser?.id ?? 'u_super');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vehicle approved.')),
                    );
                  },
                  onReject: (reason) {
                    vehicles.reject(
                        vehicle.id, reason, auth.currentUser?.id ?? 'u_super');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vehicle rejected.')),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _detailRows(Vehicle v) {
    final rows = <Widget>[];
    void card(String label, {String? value, Widget? widget}) {
      if (widget == null && (value == null || value.isEmpty)) return;
      rows.add(DetailFieldCard(
          label: label,
          value: widget == null ? value : null,
          valueWidget: widget));
      rows.add(const SizedBox(height: AppSpacing.md));
    }

    card('Vehicle number', value: v.regNo.isEmpty ? '—' : v.regNo);
    card('Model', value: v.model);
    card('Type', value: v.fuelType?.label);
    card('Branch', value: v.branch?.label);
    card('Insurance', value: v.insurance ? 'Available' : 'Not available');
    if (v.insuranceDate != null) {
      card('Insurance date', value: Formatters.date(v.insuranceDate!));
    }
    card('FC', value: v.fc ? 'Available' : 'Not available');
    if (v.fcDate != null) card('FC date', value: Formatters.date(v.fcDate!));
    card('Permit', value: v.permit ? 'Available' : 'Not available');
    if (v.permitDate != null) {
      card('Permit date', value: Formatters.date(v.permitDate!));
    }
    card('Status', widget: StatusPill.forEntity(v.status));
    card('Remarks', value: v.remarks);
    return rows;
  }

  List<Widget> _docTiles(
      BuildContext context, LoanVehicleService vehicles, Vehicle vehicle) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    DocRef? refFor(String wire) => vehicle.uploadedDocs
        .where((d) => d.docTypeWire == wire)
        .cast<DocRef?>()
        .firstOrNull;

    Future<void> replace(String wire, PickedDoc? picked) async {
      if (picked == null) return;
      try {
        await vehicles.uploadDocument(widget.vehicleId, wire, picked);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }

    Future<void> remove(int docId) async {
      try {
        await vehicles.deleteDocument(widget.vehicleId, docId);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }

    Widget tile(String wire, String label) {
      final ref = refFor(wire);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocManagerTile(
          label: label,
          fileName: ref?.fileName,
          onTakePhoto: () async => replace(wire, await pickPhotoDoc()),
          onUpload: () async => replace(wire, await pickFileDoc()),
          onDownload: ref == null
              ? null
              : () => navigator.push(MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(
                      title: label,
                      fileName: ref.fileName,
                      loader: () => vehicles.documentBytes(ref.id),
                    ),
                  )),
          onDelete: ref == null ? null : () => remove(ref.id),
        ),
      );
    }

    return [for (final d in _docs) tile(d.$1, d.$2)];
  }

  // Read-only loan history on this vehicle — including a previous (seized)
  // customer's loan after the vehicle is re-loaned to someone new.
  List<Widget> _loanHistory(BuildContext context, Vehicle vehicle) {
    final c = context.colors;
    final loans = context.watch<LoanService>();
    final customers = context.read<LoanCustomerService>();
    final list = loans.all().where((l) => l.vehicleId == vehicle.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.lg),
      Text('Loan history',
          style: AppTextStyles.label.copyWith(color: c.textSub)),
      const SizedBox(height: AppSpacing.sm),
      for (final l in list) ...[
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LoanDetailScreen(loanId: l.id),
          )),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customers.byId(l.customerId)?.fullName ?? 'Customer',
                        style: AppTextStyles.bodyStrong
                            .copyWith(color: c.textMain)),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.currency(l.principal)} · EMI ${Formatters.currency(l.emiAmount)} · ${l.tenureMonths} mo',
                      style: AppTextStyles.caption.copyWith(color: c.textSub),
                    ),
                  ],
                ),
              ),
              _loanTag(l),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: c.textSub),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Widget _loanTag(Loan l) {
    if (l.isSeized) {
      return const StatusPill(label: 'Seized', variant: PillVariant.danger);
    }
    if (l.loanStatus == 'closed') {
      return const StatusPill(label: 'Paid', variant: PillVariant.success);
    }
    if (l.isSeizePending) {
      return const StatusPill(
          label: 'Seize pending', variant: PillVariant.warning);
    }
    if (l.loanStatus == 'overdue') {
      return const StatusPill(label: 'Overdue', variant: PillVariant.danger);
    }
    return const StatusPill(label: 'Active', variant: PillVariant.info);
  }
}
