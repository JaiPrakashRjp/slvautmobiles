import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/auth_controller.dart';
import '../../models/doc_ref.dart';
import '../../models/enums.dart';
import '../../models/picked_doc.dart';
import '../../models/vehicle.dart';
import '../../services/api_rental_service.dart';
import '../../services/rental_customer_service.dart';
import '../../services/rental_vehicle_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_styles.dart';
import '../../utils/doc_picker.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/detail_field_card.dart';
import '../../widgets/doc_manager_tile.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/status_pill.dart';
import '../document_preview_screen.dart';
import 'rent_detail_screen.dart';
import 'rental_vehicle_form_screen.dart';

/// Read-only details for a rental vehicle: its fields, documents (view / upload /
/// share / delete), the current renter / rental (with a link to the rent detail),
/// and an edit pencil. Backed by the real rental-scoped services (module =
/// rental). Tapping a vehicle card opens this instead of the edit form.
class RentalVehicleDetailsScreen extends StatefulWidget {
  const RentalVehicleDetailsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<RentalVehicleDetailsScreen> createState() =>
      _RentalVehicleDetailsScreenState();
}

class _RentalVehicleDetailsScreenState
    extends State<RentalVehicleDetailsScreen> {
  // Extra documents shown for a second-hand vehicle (previous owner).
  static const _prevOwnerDocs = {
    'prev_owner_id_proof': 'Previous owner ID proof',
    'prev_owner_photo': 'Previous owner photo',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RentalVehicleService>().refresh();
      context.read<RentalAgreementService>().refresh();
      context.read<RentalCustomerService>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vehicles = context.watch<RentalVehicleService>();
    final rentals = context.watch<RentalAgreementService>();
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
    final rental = rentals.forVehicle(vehicle.id);
    final renter = rental == null
        ? null
        : context.read<RentalCustomerService>().byId(rental.customerId);

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
                builder: (_) => RentalVehicleFormScreen(existing: vehicle),
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
                ..._detailRows(vehicle),
                // Documents (RC / FC / Insurance / Permit / …).
                const SizedBox(height: AppSpacing.lg),
                Text('Documents',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                ..._docTiles(context, vehicles, vehicle),
                // Rental.
                const SizedBox(height: AppSpacing.lg),
                Text('Rental',
                    style: AppTextStyles.label.copyWith(color: c.textSub)),
                const SizedBox(height: AppSpacing.sm),
                if (rental != null &&
                    rental.rentalStatus == 'active' &&
                    rental.isActive) ...[
                  DetailFieldCard(
                      label: 'Current renter', value: renter?.fullName ?? '—'),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'View rental',
                    icon: Icons.receipt_long_outlined,
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RentDetailScreen(rentalId: rental.id),
                    )),
                  ),
                ] else
                  const DetailFieldCard(
                      label: 'Current renter', value: 'Not currently rented'),
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
          label: label, value: widget == null ? value : null, valueWidget: widget));
      rows.add(const SizedBox(height: AppSpacing.md));
    }

    card('Vehicle ID', value: v.displayId);
    card('Vehicle number', value: v.regNo.isEmpty ? '—' : v.regNo);
    card('Type', value: v.type.label);
    card('Model', value: v.model);
    card('Chassis number', value: v.chassisNo);
    card('Fuel type', value: v.fuelType?.label);
    card('Branch', value: v.branch?.label);
    card('RC', value: v.rc ? 'Yes' : 'No');
    card('Permit', value: v.permit ? 'Yes' : 'No');
    card('Insurance', value: v.insurance ? 'Yes' : 'No');
    if (v.insuranceDate != null) {
      card('Insurance date', value: Formatters.date(v.insuranceDate!));
    }
    if (v.fcDate != null) card('FC date', value: Formatters.date(v.fcDate!));
    if (v.permitDate != null) {
      card('Permit date', value: Formatters.date(v.permitDate!));
    }
    card('Status', widget: StatusPill.forEntity(v.status));
    card('Remarks', value: v.remarks);
    return rows;
  }

  // ── Documents ──────────────────────────────────────────────────────────────
  List<Widget> _docTiles(
      BuildContext context, RentalVehicleService vehicles, Vehicle vehicle) {
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
          onDelete:
              ref == null ? null : () => _delete(messenger, vehicles, ref.id),
        ),
      );
    }

    return [
      for (final d in VehicleDocType.values) tile(d.wire, d.label),
      if (vehicle.type == VehicleType.secondHand)
        for (final e in _prevOwnerDocs.entries) tile(e.key, e.value),
    ];
  }

  Future<void> _replace(ScaffoldMessengerState messenger,
      RentalVehicleService vehicles, String docTypeWire, PickedDoc? picked) async {
    if (picked == null) return;
    try {
      await vehicles.uploadDocument(widget.vehicleId, docTypeWire, picked);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _delete(ScaffoldMessengerState messenger,
      RentalVehicleService vehicles, int docId) async {
    try {
      await vehicles.deleteDocument(widget.vehicleId, docId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _shareDoc(ScaffoldMessengerState messenger,
      RentalVehicleService vehicles, DocRef ref, String label) async {
    try {
      final bytes = await vehicles.documentBytes(ref.id);
      if (bytes.isEmpty) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Nothing to share.')));
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
}
