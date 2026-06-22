import 'dart:async';
import 'dart:typed_data';

import '../models/doc_ref.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import '../models/vehicle.dart';
import 'api_client.dart';
import 'gate.dart';
import 'vehicle_service.dart';

/// Real [VehicleService] backed by the FastAPI backend.
///
/// Keeps an in-memory cache of vehicles so the synchronous list getters
/// (`all()`, `available()`, …) and `ChangeNotifier` reactivity keep working as
/// before; the cache is filled by [refresh] and updated after each mutation.
class ApiVehicleService extends VehicleService {
  ApiVehicleService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<Vehicle> _vehicles = [];

  // Until the users module + auth land, the backend requires a numeric creator.
  // Use a fixed dev placeholder (1) so records can be created.
  static const _devUserId = 1;

  // ── Reads ─────────────────────────────────────────────────────────────────
  @override
  Future<void> refresh() async {
    final data = await _api.get('/vehicles');
    _vehicles
      ..clear()
      ..addAll((data as List).map((j) => _fromJson(j as Map<String, dynamic>)));
    notifyListeners();
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
  List<Vehicle> available() =>
      _vehicles.where((v) => !v.isAssigned && v.isActive).toList();

  @override
  Vehicle? byId(String id) =>
      _vehicles.where((v) => v.id == id).cast<Vehicle?>().firstOrNull;

  // ── Create ──────────────────────────────────────────────────────────────--
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
    bool rcPermit = false,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    EntityStatus? status,
    String? assignToCustomerId,
  }) async {
    final isSecondHand = type == VehicleType.secondHand;
    final body = <String, dynamic>{
      'module_code': 'auto_sale',
      'owned_hand': type.wire,
      'branch': branch?.wire,
      'chassis_no': chassisNo,
      'model': model,
      'fuel_type': fuelType?.wire,
      'purchase_date': _date(purchaseDate),
      'buying_expenses': buyingExpenses,
      // first-hand only
      'showroom': isSecondHand ? null : showroom?.wire,
      'rc_permit': isSecondHand ? null : rcPermit,
      // second-hand only
      'reg_no': isSecondHand && regNo.isNotEmpty ? regNo : null,
      'insurance_date': isSecondHand ? _date(insuranceDate) : null,
      'fc_date': isSecondHand ? _date(fcDate) : null,
      'permit_date': isSecondHand ? _date(permitDate) : null,
      'prev_owner_name': isSecondHand ? prevOwnerName : null,
      'prev_owner_mobile': isSecondHand ? prevOwnerMobile : null,
      'prev_owner_address': isSecondHand ? prevOwnerAddress : null,
      // Do NOT send status on create — backend derives it from actor_role.
      // Status is only sent on PATCH (edit) calls.
    }..removeWhere((_, v) => v == null);

    final json = await _api.post(
      '/vehicles',
      body: body,
      query: {
        'created_by': int.tryParse(actorId) ?? _devUserId,
        'actor_role': actorRole.wire,
      },
    );
    final vehicle = _fromJson(json as Map<String, dynamic>);
    _vehicles.insert(0, vehicle);
    notifyListeners();
    return vehicle;
  }

  @override
  Future<void> uploadDocument(
      String vehicleId, String docTypeWire, PickedDoc doc) async {
    await _api.postMultipart(
      '/vehicles/$vehicleId/documents',
      fields: {'doc_type': docTypeWire},
      fileField: 'file',
      filename: doc.name,
      bytes: doc.bytes,
      mimeType: doc.mimeType ?? PickedDoc.mimeFor(doc.name),
    );
    await _reload(vehicleId);
  }

  @override
  Future<void> deleteDocument(String vehicleId, int docId) async {
    await _api.delete('/vehicles/documents/$docId');
    await _reload(vehicleId);
  }

  @override
  String documentUrl(int docId) => _api.absoluteUrl('/vehicles/documents/$docId');

  @override
  Future<Uint8List> documentBytes(int docId) =>
      _api.getBytes('/vehicles/documents/$docId');

  /// Re-fetches one vehicle and updates the cache (keeps documents in sync).
  Future<void> _reload(String vehicleId) async {
    final json = await _api.get('/vehicles/$vehicleId');
    final fresh = _fromJson(json as Map<String, dynamic>);
    final i = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (i != -1) {
      _vehicles[i] = fresh;
    } else {
      _vehicles.insert(0, fresh);
    }
    notifyListeners();
  }

  // ── Mutations ──────────────────────────────────────────────────────────--
  @override
  void confirm(String id, String byUserId) {
    final v = byId(id);
    if (v == null) return;
    Gate.confirm(v, byUserId: byUserId); // optimistic local update
    notifyListeners();
    unawaited(_api
        .post('/vehicles/$id/confirm', query: {'by_user_id': _devUserId})
        .catchError((_) => null));
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final v = byId(id);
    if (v == null) return;
    Gate.reject(v, reason: reason, byUserId: byUserId);
    notifyListeners();
    unawaited(_api.post('/vehicles/$id/reject',
        query: {'reason': reason, 'by_user_id': _devUserId}).catchError((_) => null));
  }

  @override
  void delete(String id) {
    _vehicles.removeWhere((v) => v.id == id);
    notifyListeners();
    unawaited(_api.delete('/vehicles/$id').catchError((_) => null));
  }

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
    bool? rcPermit,
    DateTime? insuranceDate,
    DateTime? fcDate,
    DateTime? permitDate,
    String? prevOwnerName,
    String? prevOwnerMobile,
    String? prevOwnerAddress,
    SaleStatus? saleStatus,
    EntityStatus? status,
  }) async {
    final body = <String, dynamic>{
      'branch': branch?.wire,
      'owned_hand': type?.wire,
      'reg_no': regNo,
      'chassis_no': chassisNo,
      'model': model,
      'fuel_type': fuelType?.wire,
      'buying_expenses': buyingExpenses,
      'showroom': showroom?.wire,
      'rc_permit': rcPermit,
      'insurance_date': _date(insuranceDate),
      'fc_date': _date(fcDate),
      'permit_date': _date(permitDate),
      'prev_owner_name': prevOwnerName,
      'prev_owner_mobile': prevOwnerMobile,
      'prev_owner_address': prevOwnerAddress,
      'sale_status': saleStatus?.wire,
      'status': status?.wire,
    }..removeWhere((_, v) => v == null);

    final json = await _api.patch('/vehicles/$id', body: body);
    final fresh = _fromJson(json as Map<String, dynamic>);
    final i = _vehicles.indexWhere((v) => v.id == id);
    if (i != -1) {
      _vehicles[i] = fresh;
    } else {
      _vehicles.insert(0, fresh);
    }
    notifyListeners();
    return fresh;
  }

  // No backend endpoints yet — keep these local-only (used by the sale/rental
  // flows). They'll move server-side when those modules are wired.
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

  // ── JSON mapping ──────────────────────────────────────────────────────────
  static String? _date(DateTime? d) =>
      d?.toIso8601String().split('T').first;

  static DateTime? _parseDate(dynamic s) =>
      (s is String && s.isNotEmpty) ? DateTime.tryParse(s) : null;

  Vehicle _fromJson(Map<String, dynamic> j) {
    final docs = (j['documents'] as List?)
            ?.map((d) => DocRef.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return Vehicle(
      id: j['id'].toString(),
      regNo: (j['reg_no'] as String?) ?? '',
      type: VehicleType.fromWire(j['owned_hand'] as String),
      branch: j['branch'] != null ? Branch.fromWire(j['branch'] as String) : null,
      purchaseDate: _parseDate(j['purchase_date']),
      chassisNo: j['chassis_no'] as String?,
      model: j['model'] as String?,
      fuelType: FuelType.fromWire(j['fuel_type'] as String?),
      buyingExpenses: j['buying_expenses'] == null
          ? null
          : num.tryParse(j['buying_expenses'].toString()),
      showroom: Showroom.fromWire(j['showroom'] as String?),
      rcPermit: (j['rc_permit'] as bool?) ?? false,
      insuranceDate: _parseDate(j['insurance_date']),
      fcDate: _parseDate(j['fc_date']),
      permitDate: _parseDate(j['permit_date']),
      prevOwnerName: j['prev_owner_name'] as String?,
      prevOwnerMobile: j['prev_owner_mobile'] as String?,
      prevOwnerAddress: j['prev_owner_address'] as String?,
      assignedToCustomerId: j['assigned_to_customer_id']?.toString(),
      inventoryStatus: InventoryStatus.fromWire(
          (j['inventory_status'] as String?) ?? 'available'),
      saleStatus: SaleStatus.fromWire(j['sale_status'] as String?),
      nextServiceDueDate: _parseDate(j['next_service_due_date']),
      createdBy: j['created_by']?.toString() ?? '',
      createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
      status: EntityStatus.fromWire((j['status'] as String?) ?? 'active'),
      confirmedBy: j['confirmed_by']?.toString(),
      confirmedAt: _parseDate(j['confirmed_at']),
      rejectionReason: j['rejection_reason'] as String?,
      uploadedDocs: docs,
    );
  }
}
