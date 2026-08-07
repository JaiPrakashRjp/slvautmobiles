import 'package:flutter/foundation.dart';

import '../models/doc_ref.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import '../models/vehicle.dart';
import '../utils/id_gen.dart';
import 'gate.dart';

abstract class VehicleService extends ChangeNotifier {
  List<Vehicle> all();
  List<Vehicle> assigned();
  List<Vehicle> unassigned();
  List<Vehicle> sold();
  List<Vehicle> notSold();
  List<Vehicle> available();
  Vehicle? byId(String id);

  /// True while a [refresh] is in flight (drives the list loading spinner).
  bool get loading => false;

  /// Loads vehicles from the backing store (no-op for the in-memory mock).
  Future<void> refresh() async {}

  Future<Vehicle> create({
    required Role actorRole,
    required String actorId,
    required String regNo,
    required VehicleType type,
    Branch? branch,
    DateTime? purchaseDate,
    String? chassisNo,
    String? model,
    FuelType? fuelType,
    num? buyingExpenses,
    Showroom? showroom,
    bool rc = false,
    bool permit = false,
    bool insurance = false,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    DateTime? nextServiceDueDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    EntityStatus? status,
    String? assignToCustomerId,
    String? remarks,
    int? financerId,
  });

  /// Uploads one picked file for a vehicle (upsert by doc type — replaces an
  /// existing file of the same type). [docTypeWire] is the backend
  /// `vehicle_doc_type` value (e.g. `rc`, `prev_owner_id_proof`).
  Future<void> uploadDocument(
      String vehicleId, String docTypeWire, PickedDoc doc);

  /// Deletes a stored document by its backend id.
  Future<void> deleteDocument(String vehicleId, int docId);

  /// Absolute URL to download/view a stored document (empty for the mock).
  String documentUrl(int docId);

  /// Raw bytes of a stored document, for in-app preview.
  Future<Uint8List> documentBytes(int docId);

  /// Edits an existing vehicle (PATCH). Only non-null fields are changed.
  Future<Vehicle> update(
    String id, {
    Branch? branch,
    VehicleType? type,
    String? regNo,
    String? chassisNo,
    String? model,
    FuelType? fuelType,
    num? buyingExpenses,
    Showroom? showroom,
    bool? rc,
    bool? permit,
    bool? insurance,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    DateTime? nextServiceDueDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    SaleStatus? saleStatus,
    EntityStatus? status,
    String? remarks,
    int? financerId,
  });

  void delete(String id);
  void confirm(String id, String byUserId);
  void reject(String id, String reason, String byUserId);

  /// Assignment helpers used by Sale / Rental services.
  void assignTo(String vehicleId, String customerId, InventoryStatus status);
  void release(String vehicleId);
}

class MockVehicleService extends VehicleService {
  MockVehicleService() {
    _seed();
  }

  final List<Vehicle> _vehicles = [];

  void _seed() {
    IdGen.seedAtLeast('v', 3);
    _vehicles.addAll([
      Vehicle(
        id: 'v_001',
        regNo: 'KA-01-AB-1234',
        type: VehicleType.firstHand,
        purchaseDate: DateTime(2026, 1, 15),
        assignedToCustomerId: 'c_001',
        inventoryStatus: InventoryStatus.sold,
        createdBy: 'u_super',
        createdAt: DateTime(2026, 1, 16),
        status: EntityStatus.active,
      ),
      Vehicle(
        id: 'v_002',
        regNo: 'KA-05-CJ-7788',
        type: VehicleType.secondHand,
        purchaseDate: DateTime(2026, 2, 10),
        inventoryStatus: InventoryStatus.available,
        createdBy: 'u_super',
        createdAt: DateTime(2026, 2, 11),
        status: EntityStatus.active,
      ),
      Vehicle(
        id: 'v_003',
        regNo: 'KA-03-MN-4521',
        type: VehicleType.firstHand,
        purchaseDate: DateTime(2026, 5, 20),
        inventoryStatus: InventoryStatus.available,
        createdBy: 'u_admin_ravi',
        createdAt: DateTime(2026, 5, 26),
        status: EntityStatus.pendingConfirmation,
      ),
    ]);
  }

  @override
  List<Vehicle> all() => List.unmodifiable(_vehicles);

  @override
  List<Vehicle> assigned() => _vehicles.where((v) => v.isAssigned).toList();

  @override
  List<Vehicle> unassigned() => _vehicles.where((v) => !v.isAssigned).toList();

  @override
  List<Vehicle> sold() =>
      _vehicles.where((v) => v.saleStatus == SaleStatus.sold).toList();

  @override
  List<Vehicle> notSold() =>
      _vehicles.where((v) => v.saleStatus == SaleStatus.notSold).toList();

  @override
  List<Vehicle> available() => _vehicles
      .where((v) => !v.isAssigned && v.isActive && !v.isSeized)
      .toList();

  @override
  Vehicle? byId(String id) =>
      _vehicles.where((v) => v.id == id).cast<Vehicle?>().firstOrNull;

  @override
  Future<Vehicle> create({
    required Role actorRole,
    required String actorId,
    required String regNo,
    required VehicleType type,
    Branch? branch,
    DateTime? purchaseDate,
    String? chassisNo,
    String? model,
    FuelType? fuelType,
    num? buyingExpenses,
    Showroom? showroom,
    bool rc = false,
    bool permit = false,
    bool insurance = false,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    DateTime? nextServiceDueDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    EntityStatus? status,
    String? assignToCustomerId,
    String? remarks,
    int? financerId,
  }) async {
    final vehicle = Vehicle(
      id: IdGen.nextId('v'),
      regNo: regNo,
      type: type,
      branch: branch,
      purchaseDate: purchaseDate,
      chassisNo: chassisNo,
      model: model,
      fuelType: fuelType,
      buyingExpenses: buyingExpenses,
      showroom: showroom,
      rc: rc,
      permit: permit,
      insurance: insurance,
      insuranceDate: insuranceDate,
      fcDate: fcDate,
      permitDate: permitDate,
      prevOwnerName: prevOwnerName,
      prevOwnerMobile: prevOwnerMobile,
      prevOwnerAddress: prevOwnerAddress,
      assignedToCustomerId: assignToCustomerId,
      inventoryStatus: assignToCustomerId != null
          ? InventoryStatus.reserved
          : InventoryStatus.available,
      remarks: remarks,
      financerId: financerId,
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: status ?? Gate.initialStatus(actorRole),
    );
    _vehicles.insert(0, vehicle);
    notifyListeners();
    return vehicle;
  }

  int _mockDocId = 0;

  @override
  Future<void> uploadDocument(
      String vehicleId, String docTypeWire, PickedDoc doc) async {
    // In-memory only: record an uploaded-doc reference for display.
    final v = byId(vehicleId);
    if (v == null) return;
    v.uploadedDocs.removeWhere((d) => d.docTypeWire == docTypeWire); // upsert
    v.uploadedDocs.add(
      DocRef(id: ++_mockDocId, docTypeWire: docTypeWire, fileName: doc.name),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteDocument(String vehicleId, int docId) async {
    final v = byId(vehicleId);
    if (v == null) return;
    v.uploadedDocs.removeWhere((d) => d.id == docId);
    notifyListeners();
  }

  @override
  String documentUrl(int docId) => ''; // no backend in the mock

  @override
  Future<Uint8List> documentBytes(int docId) async => Uint8List(0);

  @override
  Future<Vehicle> update(
    String id, {
    Branch? branch,
    VehicleType? type,
    String? regNo,
    String? chassisNo,
    String? model,
    FuelType? fuelType,
    num? buyingExpenses,
    Showroom? showroom,
    bool? rc,
    bool? permit,
    bool? insurance,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    DateTime? nextServiceDueDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    SaleStatus? saleStatus,
    EntityStatus? status,
    String? remarks,
    int? financerId,
  }) async {
    final v = byId(id)!;
    if (branch != null) v.branch = branch;
    if (type != null) v.type = type;
    if (regNo != null) v.regNo = regNo;
    if (chassisNo != null) v.chassisNo = chassisNo;
    if (model != null) v.model = model;
    if (fuelType != null) v.fuelType = fuelType;
    if (buyingExpenses != null) v.buyingExpenses = buyingExpenses;
    if (showroom != null) v.showroom = showroom;
    if (rc != null) v.rc = rc;
    if (permit != null) v.permit = permit;
    if (insurance != null) v.insurance = insurance;
    if (insuranceDate != null) v.insuranceDate = insuranceDate;
    if (fcDate != null) v.fcDate = fcDate;
    if (permitDate != null) v.permitDate = permitDate;
    if (prevOwnerName != null) v.prevOwnerName = prevOwnerName;
    if (prevOwnerMobile != null) v.prevOwnerMobile = prevOwnerMobile;
    if (prevOwnerAddress != null) v.prevOwnerAddress = prevOwnerAddress;
    if (saleStatus != null) v.saleStatus = saleStatus;
    if (status != null) v.status = status;
    if (remarks != null) v.remarks = remarks;
    if (financerId != null) v.financerId = financerId;
    notifyListeners();
    return v;
  }

  @override
  void delete(String id) {
    _vehicles.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  @override
  void confirm(String id, String byUserId) {
    final v = byId(id);
    if (v != null) {
      Gate.confirm(v, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final v = byId(id);
    if (v != null) {
      Gate.reject(v, reason: reason, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void assignTo(String vehicleId, String customerId, InventoryStatus status) {
    final v = byId(vehicleId);
    if (v != null) {
      v.assignedToCustomerId = customerId;
      v.inventoryStatus = status;
      notifyListeners();
    }
  }

  @override
  void release(String vehicleId) {
    final v = byId(vehicleId);
    if (v != null) {
      v.assignedToCustomerId = null;
      v.inventoryStatus = InventoryStatus.available;
      notifyListeners();
    }
  }
}
