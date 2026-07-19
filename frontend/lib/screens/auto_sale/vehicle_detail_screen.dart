import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../models/sale.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
import '../../services/financer_service.dart';
import '../../services/pdf_service.dart';
import '../../services/sale_service.dart';
import '../../services/vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/detail_field_card.dart';
import '../../widgets/doc_manager_tile.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_gate_actions.dart';
import '../../widgets/role_gate_banner.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';
import '../pdf_preview_screen.dart';
import 'assign_sale_screen.dart';
import 'create_vehicle_screen.dart';
import 'create_customer_screen.dart';
import 'customer_detail_screen.dart';
import 'sale_detail_screen.dart';

/// Vehicle detail — read-only fields + role-gate approve/reject + edit +
/// document management (download / replace / delete).
class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  // Documents shown for a second-hand vehicle: the standard set + previous-owner.
  static const _prevOwnerDocs = {
    'prev_owner_id_proof': 'Previous owner ID proof',
    'prev_owner_photo': 'Previous owner photo',
  };

  Future<void> _replace(ScaffoldMessengerState messenger, VehicleService vehicles,
      String docTypeWire, PickedDoc? picked) async {
    if (picked == null) return;
    try {
      await vehicles.uploadDocument(vehicleId, docTypeWire, picked);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _delete(
      ScaffoldMessengerState messenger, VehicleService vehicles, int docId) async {
    try {
      await vehicles.deleteDocument(vehicleId, docId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  /// Fetch the document bytes and hand them to the OS share sheet
  /// (WhatsApp / email / Drive …).
  Future<void> _shareDoc(ScaffoldMessengerState messenger,
      VehicleService vehicles, DocRef ref, String label) async {
    try {
      final bytes = await vehicles.documentBytes(ref.id);
      if (bytes.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Nothing to share.')));
        return;
      }
      final name = ref.fileName.isEmpty ? 'document' : ref.fileName;
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: _mimeFor(name))],
        subject: label,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  static String _mimeFor(String fileName) {
    final f = fileName.toLowerCase();
    if (f.endsWith('.pdf')) return 'application/pdf';
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Unsell: ask for a reason then cancel the active sale and reset the vehicle.
  Future<void> _unsell(BuildContext context, SaleService sales,
      VehicleService vehicles, String saleId, String byUserId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsell vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Why is this sale being cancelled? The reason will be saved on the record.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm unsell',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    try {
      await sales.cancel(saleId, reason, byUserId);
      await vehicles.refresh();
      if (!context.mounted) return;
      final pending = sales.byId(saleId)?.isUnsellPending ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(pending
                ? 'Unsell requested — awaiting super-admin approval.'
                : 'Sale cancelled. Vehicle is now available.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Seize: repossess the vehicle from a defaulting customer. Keeps the sale as
  /// history (status seized) and frees the vehicle to re-sell. No time limit.
  Future<void> _seize(BuildContext context, SaleService sales,
      VehicleService vehicles, String saleId, String byUserId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seize vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Repossess this vehicle from the customer? The sale and its '
                'payment history are kept as a record, and the vehicle becomes '
                'available to re-sell.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for seizure…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm seize',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    try {
      await sales.seize(saleId, reason, byUserId);
      await vehicles.refresh();
      if (!context.mounted) return;
      final pending = sales.byId(saleId)?.isSeizePending ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(pending
                ? 'Seize requested — awaiting super-admin approval.'
                : 'Vehicle seized.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Small remarks-prompt dialog; returns the trimmed text, or null if cancelled
  /// or left empty.
  Future<String?> _askRemarks(
      BuildContext context, String title, String hint) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
              hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return (ok == true && text.isNotEmpty) ? text : null;
  }

  /// Cancel an active seizure — the vehicle goes back to the same customer.
  Future<void> _cancelSeize(BuildContext context, SaleService sales,
      VehicleService vehicles, String saleId) async {
    final remarks = await _askRemarks(context, 'Cancel seizure',
        'The vehicle returns to the customer. Add remarks…');
    if (remarks == null || !context.mounted) return;
    try {
      await sales.cancelSeize(saleId, remarks);
      await vehicles.refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Seizure cancelled — vehicle returned to the customer.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Confirm (finalise) an active seizure — the vehicle becomes a normal free
  /// vehicle; the seized sale stays as history.
  Future<void> _confirmSeize(BuildContext context, SaleService sales,
      VehicleService vehicles, String saleId) async {
    final remarks = await _askRemarks(context, 'Confirm seizure',
        'Finalise the seizure. The vehicle becomes available. Add remarks…');
    if (remarks == null || !context.mounted) return;
    try {
      await sales.confirmSeize(saleId, remarks);
      await vehicles.refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seizure confirmed.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Sell this vehicle: pick a verified customer, then open the sale screen with
  /// the vehicle pre-selected.
  Future<void> _sell(BuildContext context, CustomerService customers) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Active AND pending customers (not rejected); pending ones are marked and
    // can't be sold to until the super admin approves them.
    final listable =
        customers.all().where((c) => c.isActive || c.isPending).toList();
    final customerId = await OptionSheet.show<String>(
      context,
      title: 'Sell to customer',
      searchable: true,
      searchHint: 'Search by name or phone',
      addLabel: 'New customer',
      onAdd: () => navigator.push(MaterialPageRoute(
        builder: (_) => CreateCustomerScreen(sellVehicleId: vehicleId),
      )),
      options: listable
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle:
                    c.isActive ? c.phone : '${c.phone}  ·  Pending approval',
              ))
          .toList(),
    );
    if (customerId == null) return;
    final chosen = customers.byId(customerId);
    if (chosen != null && !chosen.isActive) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'This customer is still pending approval. You can sell once it is approved.'),
      ));
      return;
    }
    await navigator.push(MaterialPageRoute(
      builder: (_) => AssignSaleScreen(
        customerId: customerId,
        initialVehicleId: vehicleId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    context.watch<VehicleService>();
    context.watch<SaleService>();
    context.watch<FinancerService>();
    final vehicles = context.read<VehicleService>();
    final customers = context.read<CustomerService>();
    final sales = context.read<SaleService>();
    final financers = context.read<FinancerService>();
    final auth = context.read<AuthController>();

    // Re-pull the vehicle + its sale/customer so seize state (approve/cancel/
    // confirm made elsewhere) shows without a re-login. Backs auto-refresh on
    // open and pull-to-refresh.
    Future<void> refreshAll() => Future.wait([
          vehicles.refresh(),
          sales.refresh(),
          customers.refresh(),
        ]);

    final vehicle = vehicles.byId(vehicleId);
    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle detail')),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final assignedName = vehicle.assignedToCustomerId == null
        ? 'Not assigned'
        : customers.byId(vehicle.assignedToCustomerId!)?.fullName ?? 'Unknown';
    final financerName = vehicle.financerId == null
        ? null
        : financers.byId(vehicle.financerId!)?.name;
    final sale = sales.forVehicle(vehicle.id);
    // Admins can modify only what they created; super admin can modify anything.
    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Vehicle detail'),
        actions: [
          // Buyer invoice — only for second-hand vehicles (the shop's record of
          // buying the used vehicle). Opens the preview; share from there.
          if (vehicle.type == VehicleType.secondHand)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Buyer invoice',
              onPressed: () {
                final pdf = context.read<PdfService>();
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PdfPreviewScreen(
                    title: 'Buyer invoice',
                    fileName: 'buyer-invoice-${vehicle.displayId}.pdf',
                    builder: () => pdf.buyerInvoiceBytes(vehicle: vehicle),
                  ),
                ));
              },
            ),
          if (canModify)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateVehicleScreen(existing: vehicle),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxFormWidth: 560,
          phone: RefreshIndicator(
            onRefresh: refreshAll,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              _AutoRefreshTrigger(onInit: refreshAll),
              if (!vehicle.isActive) ...[
                RoleGateBanner(
                  status: vehicle.status,
                  rejectionReason: vehicle.rejectionReason,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              ..._detailRows(context, vehicle, assignedName, financerName),
              if (vehicle.type == VehicleType.secondHand) ...[
                ..._prevOwnerRows(context, vehicle),
                const SizedBox(height: AppSpacing.lg),
                Text('Documents',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                ..._docTiles(context, vehicles, vehicle),
              ],
              if (canModify &&
                  vehicle.isActive &&
                  vehicle.saleStatus == SaleStatus.notSold &&
                  sale == null) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Sell this vehicle',
                  icon: Icons.sell_outlined,
                  onPressed: () => _sell(context, customers),
                ),
              ],
              if (vehicle.saleStatus == SaleStatus.sold) ...[
                const SizedBox(height: AppSpacing.lg),
                _SoldBanner(
                  customerName: assignedName,
                  onTap: vehicle.assignedToCustomerId == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(
                                customerId: vehicle.assignedToCustomerId!),
                          )),
                ),
              ],
              if (sale != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: 'View sale detail',
                  icon: Icons.receipt_long_outlined,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SaleDetailScreen(saleId: sale.id),
                    ),
                  ),
                ),
              ],
              // Unsell: sold + active sale + modify rights, within the 1-day
              // window (Sale.canUnsell), and not already awaiting approval.
              // Admin's request is held pending a super admin; super admin's is
              // immediate (handled in _unsell).
              if (canModify &&
                  vehicle.saleStatus == SaleStatus.sold &&
                  sale != null &&
                  sale.saleStatus == 'active' &&
                  sale.canUnsell &&
                  !sale.isUnsellPending) ...[
                const SizedBox(height: AppSpacing.md),
                _UnsellButton(
                  onTap: () => _unsell(
                    context,
                    sales,
                    vehicles,
                    sale.id,
                    auth.currentUser?.id ?? '',
                  ),
                ),
              ],
              // Seize: sold + modify rights. Hidden once the sale is confirmed
              // sold (fully paid + confirmed) — a sold-off customer owns the
              // vehicle, so there is nothing to repossess. No time limit.
              if (canModify &&
                  vehicle.saleStatus == SaleStatus.sold &&
                  sale != null &&
                  sale.saleStatus == 'active' &&
                  !sale.sold) ...[
                const SizedBox(height: AppSpacing.md),
                _SeizeButton(
                  onTap: () => _seize(
                    context,
                    sales,
                    vehicles,
                    sale.id,
                    auth.currentUser?.id ?? '',
                  ),
                ),
              ],
              // Seizure history: previous customer(s) this vehicle was seized
              // from. Tap to see the full (read-only) sale + payment history.
              ...(() {
                final seized = sales.seizedForVehicle(vehicle.id);
                if (seized.isEmpty) return const <Widget>[];
                return [
                  const SizedBox(height: AppSpacing.lg),
                  _SeizedHistorySection(
                    seized: seized,
                    customers: customers,
                    canManage: canModify,
                    onOpen: (s) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SaleDetailScreen(saleId: s.id),
                      ),
                    ),
                    onCancelSeize: (s) =>
                        _cancelSeize(context, sales, vehicles, s.id),
                    onConfirmSeize: (s) =>
                        _confirmSeize(context, sales, vehicles, s.id),
                  ),
                ];
              })(),
              const SizedBox(height: AppSpacing.lg),
              RoleGateActions(
                status: vehicle.status,
                onApprove: () {
                  vehicles.confirm(vehicle.id, auth.currentUser?.id ?? 'u_super');
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
            ],
          ),
          ),
        ),
      ),
    );
  }

  /// All read-only fields for the vehicle (common + hand-specific).
  List<Widget> _detailRows(
      BuildContext context, Vehicle v, String assignedName, String? financerName) {
    final c = context.colors;
    final rows = <Widget>[];
    void card(String label, {String? value, Widget? widget, Color? color}) {
      if (widget == null && (value == null || value.isEmpty)) return;
      rows.add(DetailFieldCard(
        label: label,
        value: widget == null ? value : null,
        valueWidget: widget,
        valueColor: color,
      ));
      rows.add(const SizedBox(height: AppSpacing.md));
    }

    // A document date is "expired" on/after its date — shown in red.
    final today = DateUtils.dateOnly(DateTime.now());
    bool expired(DateTime d) => !DateUtils.dateOnly(d).isAfter(today);
    Color? dateColor(DateTime d) => expired(d) ? c.danger : null;

    card('Vehicle ID', value: v.displayId);
    card('Vehicle number', value: v.regNo.isEmpty ? '—' : v.regNo);
    card('Type', value: v.type.label);
    card('Branch', value: v.branch?.label);
    card('Chassis number', value: v.chassisNo);
    card('Model', value: v.model);
    card('Fuel type', value: v.fuelType?.label);
    if (v.purchaseDate != null) {
      card('Purchase date', value: Formatters.date(v.purchaseDate!));
    }
    if (v.buyingExpenses != null) {
      card('Buying expenses', value: Formatters.currency(v.buyingExpenses!));
    }
    if (v.type == VehicleType.firstHand) {
      card('Showroom', value: v.showroom?.label);
    }
    card('RC', value: v.rc ? 'Yes' : 'No');
    card('Permit', value: v.permit ? 'Yes' : 'No');
    card('Insurance', value: v.insurance ? 'Yes' : 'No');
    if (v.insuranceDate != null) {
      card('Insurance date',
          value: Formatters.date(v.insuranceDate!),
          color: dateColor(v.insuranceDate!));
    }
    if (v.fcDate != null) {
      card('FC date',
          value: Formatters.date(v.fcDate!), color: dateColor(v.fcDate!));
    }
    if (v.permitDate != null) {
      card('Permit date',
          value: Formatters.date(v.permitDate!), color: dateColor(v.permitDate!));
    }
    card('Financer', value: financerName);
    card('Status', widget: StatusPill.forEntity(v.status));
    card('Sale status', value: v.saleStatus.label);
    card('Assigned to', value: assignedName);
    card('Remarks', value: v.remarks);
    return rows;
  }

  /// Previous-owner block (second-hand only). Empty if nothing was captured.
  List<Widget> _prevOwnerRows(BuildContext context, Vehicle v) {
    final c = context.colors;
    final fields = <Widget>[];
    void card(String label, String? value) {
      if (value == null || value.isEmpty) return;
      fields.add(DetailFieldCard(label: label, value: value));
      fields.add(const SizedBox(height: AppSpacing.md));
    }

    card('Name', v.prevOwnerName);
    card('Mobile number', v.prevOwnerMobile);
    card('Address', v.prevOwnerAddress);
    if (fields.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Text('Previous owner details',
          style: AppTextStyles.label.copyWith(color: c.textSub)),
      const SizedBox(height: AppSpacing.sm),
      ...fields,
    ];
  }

  List<Widget> _docTiles(
      BuildContext context, VehicleService vehicles, Vehicle vehicle) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    DocRef? refFor(String wire) => vehicle.uploadedDocs
        .where((d) => d.docTypeWire == wire)
        .cast<DocRef?>()
        .firstOrNull;

    Widget tile(String wire, String label) {
      final ref = refFor(wire);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DocManagerTile(
          label: label,
          fileName: ref?.fileName,
          onTakePhoto: () async =>
              _replace(messenger, vehicles, wire, await pickPhotoDoc()),
          onUpload: () async =>
              _replace(messenger, vehicles, wire, await pickFileDoc()),
          onDownload: ref == null
              ? null
              : () => navigator.push(MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(
                      title: label,
                      fileName: ref.fileName,
                      loader: () => vehicles.documentBytes(ref.id),
                    ),
                  )),
          onShare: ref == null
              ? null
              : () => _shareDoc(messenger, vehicles, ref, label),
          onDelete: ref == null ? null : () => _delete(messenger, vehicles, ref.id),
        ),
      );
    }

    return [
      for (final d in VehicleDocType.values) tile(d.wire, d.label),
      for (final e in _prevOwnerDocs.entries) tile(e.key, e.value),
    ];
  }
}

/// Danger-toned unsell button shown below the sold banner.
class _UnsellButton extends StatelessWidget {
  const _UnsellButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, color: c.danger, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Unsell vehicle',
                style: AppTextStyles.bodyStrong.copyWith(color: c.danger)),
          ],
        ),
      ),
    );
  }
}

/// Danger-toned seize (repossess) button.
class _SeizeButton extends StatelessWidget {
  const _SeizeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gavel_rounded, color: c.danger, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Seize vehicle',
                style: AppTextStyles.bodyStrong.copyWith(color: c.danger)),
          ],
        ),
      ),
    );
  }
}

/// Seizure history for a vehicle: each previous customer it was seized from.
/// Tapping a row opens the full (read-only) sale + payment history.
class _SeizedHistorySection extends StatelessWidget {
  const _SeizedHistorySection({
    required this.seized,
    required this.customers,
    required this.onOpen,
    required this.canManage,
    required this.onCancelSeize,
    required this.onConfirmSeize,
  });

  final List<Sale> seized;
  final CustomerService customers;
  final void Function(Sale) onOpen;
  final bool canManage;
  final void Function(Sale) onCancelSeize;
  final void Function(Sale) onConfirmSeize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.gavel_rounded, color: c.textSub, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text('Seizure history',
                style: AppTextStyles.bodyStrong.copyWith(color: c.textMain)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final s in seized) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customers.byId(s.customerId)?.fullName ??
                                'Previous customer',
                            style: AppTextStyles.bodyStrong
                                .copyWith(color: c.textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.seizedAt != null
                                ? 'Seized ${Formatters.date(s.seizedAt!)}'
                                : 'Seized',
                            style: AppTextStyles.caption
                                .copyWith(color: c.textSub),
                          ),
                          if (s.seizeReason != null &&
                              s.seizeReason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(s.seizeReason!,
                                style: AppTextStyles.caption
                                    .copyWith(color: c.textSub)),
                          ],
                          if (s.isSeizeConfirmed &&
                              (s.seizeConfirmRemarks?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 2),
                            Text('Confirmed: ${s.seizeConfirmRemarks}',
                                style: AppTextStyles.caption
                                    .copyWith(color: c.textSub)),
                          ],
                        ],
                      ),
                    ),
                    StatusPill(
                        label: s.isSeizeConfirmed ? 'Confirmed' : 'Seized',
                        variant: s.isSeizeConfirmed
                            ? PillVariant.neutral
                            : PillVariant.danger),
                    const SizedBox(width: AppSpacing.sm),
                    // Eye — view the full customer + payment history.
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      tooltip: 'View all details',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onOpen(s),
                    ),
                  ],
                ),
                // Active seize → Cancel (return to customer) / Confirm (finalise).
                if (s.isSeizeActive && canManage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onCancelSeize(s),
                          child: const Text('Cancel seize'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onConfirmSeize(s),
                          child: const Text('Confirm seize'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Small confirmation strip shown when the vehicle has already been sold.
class _SoldBanner extends StatelessWidget {
  const _SoldBanner({required this.customerName, this.onTap});

  final String customerName;

  /// Tap → open the buyer's full customer detail (when known).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.success.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: c.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  customerName == 'Not assigned'
                      ? 'This vehicle has been sold.'
                      : 'Sold to $customerName.',
                  style: AppTextStyles.body.copyWith(color: c.textMain),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: c.textSub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Invisible child that runs [onInit] once after the first frame — gives a
/// StatelessWidget an "auto-refresh on open" without converting it to stateful.
class _AutoRefreshTrigger extends StatefulWidget {
  const _AutoRefreshTrigger({required this.onInit});
  final Future<void> Function() onInit;

  @override
  State<_AutoRefreshTrigger> createState() => _AutoRefreshTriggerState();
}

class _AutoRefreshTriggerState extends State<_AutoRefreshTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInit();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
