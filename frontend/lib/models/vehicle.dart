import 'doc_ref.dart';
import 'enums.dart';
import 'gated_entity.dart';

/// An auto-rickshaw in inventory. Gated: status `active` shows as "Verified".
/// "Assigned" in the UI means it is tied to a customer (via a sale or rental).
class Vehicle with GatedEntity {
  Vehicle({
    required this.id,
    required this.regNo,
    required this.type,
    this.branch,
    this.purchaseDate,
    this.chassisNo,
    this.model,
    this.fuelType,
    this.buyingExpenses,
    this.showroom,
    this.rcPermit = false,
    this.insuranceDate,
    this.fcDate,
    this.permitDate,
    Map<VehicleDocType, String>? documents,
    this.prevOwnerName,
    this.prevOwnerMobile,
    this.prevOwnerAddress,
    this.prevOwnerIdProof,
    this.prevOwnerPhoto,
    this.assignedToCustomerId,
    this.inventoryStatus = InventoryStatus.available,
    this.saleStatus = SaleStatus.notSold,
    this.nextServiceDueDate,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    List<DocRef>? uploadedDocs,
  })  : documents = documents ?? {},
        uploadedDocs = uploadedDocs ?? [];

  @override
  final String id;

  /// Registration number. Captured for second-hand vehicles; a first-hand
  /// (new) vehicle is unregistered, so this may be empty until registration.
  String regNo;
  VehicleType type;
  Branch? branch;
  DateTime? purchaseDate;

  // Common details (both hand types).
  String? chassisNo;
  String? model;
  FuelType? fuelType;
  num? buyingExpenses;

  // First-hand only: source showroom + RC permit flag.
  Showroom? showroom;
  bool rcPermit;

  // Second-hand only: existing paperwork dates + uploaded documents.
  DateTime? insuranceDate;
  DateTime? fcDate;
  DateTime? permitDate;

  /// Uploaded documents: doc type → file name (path/URL in Phase 7 backend).
  Map<VehicleDocType, String> documents;

  // Second-hand only: previous-owner (buyer) details. ID proof / photo hold the
  // uploaded file name (path/URL in Phase 7); null = not attached.
  String? prevOwnerName;
  String? prevOwnerMobile;
  String? prevOwnerAddress;
  String? prevOwnerIdProof;
  String? prevOwnerPhoto;

  /// Customer this vehicle is currently assigned to (sale or rental), if any.
  String? assignedToCustomerId;
  InventoryStatus inventoryStatus;
  SaleStatus saleStatus;

  /// Documents already stored on the backend (for download / replace / delete).
  List<DocRef> uploadedDocs;

  /// Denormalised next-service date (most recent service + interval). Drives
  /// the service-due banner in the rental module.
  DateTime? nextServiceDueDate;

  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  @override
  EntityStatus status;
  @override
  String? confirmedBy;
  @override
  DateTime? confirmedAt;
  @override
  String? rejectionReason;

  bool get isAssigned => assignedToCustomerId != null;

  /// Display id, e.g. `VEH-001` from `v_001` or the raw id.
  String get displayId {
    final digits = RegExp(r'\d+').firstMatch(id)?.group(0);
    return digits != null ? 'VEH-${digits.padLeft(3, '0')}' : id.toUpperCase();
  }

  /// Human-readable vehicle label. Uses reg number when available (second-hand);
  /// falls back to model or type+ID for first-hand (unregistered) vehicles.
  String get displayLabel =>
      regNo.isNotEmpty ? regNo : (model ?? '${type.label} #$displayId');
}
