import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../models/vehicle.dart';
import '../../services/customer_service.dart';
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
import 'assign_sale_screen.dart';
import 'create_vehicle_screen.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale cancelled. Vehicle is now available.')),
      );
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
    final eligible = customers.all().where((c) => c.isActive).toList();
    if (eligible.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No verified customers yet. Add and confirm a customer first.'),
      ));
      return;
    }
    final customerId = await OptionSheet.show<String>(
      context,
      title: 'Sell to customer',
      searchable: true,
      searchHint: 'Search by name or phone',
      options: eligible
          .map((c) => SheetOption(
                value: c.id,
                label: c.fullName,
                subtitle: c.phone,
              ))
          .toList(),
    );
    if (customerId == null) return;
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
    final vehicles = context.read<VehicleService>();
    final customers = context.read<CustomerService>();
    final sales = context.read<SaleService>();
    final auth = context.read<AuthController>();

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
    final sale = sales.forVehicle(vehicle.id);
    // Admins can modify only what they created; super admin can modify anything.
    final canModify =
        auth.isSuperAdmin || vehicle.createdBy == auth.currentUser?.id;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Vehicle detail'),
        actions: [
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
          phone: ListView(
            padding: EdgeInsets.all(context.screenHPadding),
            children: [
              if (!vehicle.isActive) ...[
                RoleGateBanner(
                  status: vehicle.status,
                  rejectionReason: vehicle.rejectionReason,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              ..._detailRows(context, vehicle, assignedName),
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
                _SoldBanner(customerName: assignedName),
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
              // Unsell: only when sold + active sale + has modify rights
              if (canModify &&
                  vehicle.saleStatus == SaleStatus.sold &&
                  sale != null &&
                  sale.saleStatus == 'active') ...[
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
    );
  }

  /// All read-only fields for the vehicle (common + hand-specific).
  List<Widget> _detailRows(
      BuildContext context, Vehicle v, String assignedName) {
    final rows = <Widget>[];
    void card(String label, {String? value, Widget? widget}) {
      if (widget == null && (value == null || value.isEmpty)) return;
      rows.add(DetailFieldCard(
        label: label,
        value: widget == null ? value : null,
        valueWidget: widget,
      ));
      rows.add(const SizedBox(height: AppSpacing.md));
    }

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
    card('Showroom', value: v.showroom?.label); // first-hand
    if (v.insuranceDate != null) {
      card('Insurance date', value: Formatters.date(v.insuranceDate!));
    }
    if (v.fcDate != null) card('FC date', value: Formatters.date(v.fcDate!));
    if (v.permitDate != null) {
      card('Permit date', value: Formatters.date(v.permitDate!));
    }
    card('Status', widget: StatusPill.forEntity(v.status));
    card('Sale status', value: v.saleStatus.label);
    card('Assigned to', value: assignedName);
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

/// Small confirmation strip shown when the vehicle has already been sold.
class _SoldBanner extends StatelessWidget {
  const _SoldBanner({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
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
        ],
      ),
    );
  }
}
