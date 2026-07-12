import 'dart:typed_data';

import '../models/customer.dart';
import '../models/doc_ref.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import 'api_client.dart';
import 'gate.dart';
import 'customer_service.dart';

/// Real [CustomerService] backed by the FastAPI backend, with an in-memory
/// cache so the synchronous getters and reactivity keep working.
class ApiCustomerService extends CustomerService {
  ApiCustomerService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<Customer> _customers = [];
  bool _loading = false;

  @override
  bool get loading => _loading;

  @override
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.get('/customers');
      _customers
        ..clear()
        ..addAll(
            (data as List).map((j) => _fromJson(j as Map<String, dynamic>)));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  List<Customer> all() => List.unmodifiable(_customers);

  @override
  Customer? byId(String id) =>
      _customers.where((c) => c.id == id).cast<Customer?>().firstOrNull;

  @override
  Future<Customer> create({
    required Role actorRole,
    required String actorId,
    required String firstName,
    String lastName = '',
    required String phone,
    String address = '',
    Branch? branch,
    int? age,
    DateTime? dob,
    String? assurityName,
    String? assurityMobile,
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'module_code': 'auto_sale',
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'address': address,
      'branch': branch?.wire,
      'age': age,
      'dob': _date(dob),
      'assurity_name': assurityName,
      'assurity_mobile': assurityMobile,
      'remarks': remarks,
    }..removeWhere((_, v) => v == null);

    // created_by + actor_role are derived from the Bearer token server-side.
    final json = await _api.post('/customers', body: body);
    final customer = _fromJson(json as Map<String, dynamic>);
    _customers.insert(0, customer);
    notifyListeners();
    return customer;
  }

  @override
  Future<Customer> update(
    String id, {
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    Branch? branch,
    int? age,
    DateTime? dob,
    String? assurityName,
    String? assurityMobile,
    EntityStatus? status,
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'address': address,
      'branch': branch?.wire,
      'age': age,
      'dob': _date(dob),
      'assurity_name': assurityName,
      'assurity_mobile': assurityMobile,
      'status': status?.wire,
      'remarks': remarks,
    }..removeWhere((_, v) => v == null);

    final json = await _api.patch('/customers/$id', body: body);
    final fresh = _fromJson(json as Map<String, dynamic>);
    _replaceInCache(fresh);
    notifyListeners();
    return fresh;
  }

  @override
  Future<void> uploadDocument(
      String customerId, String docTypeWire, PickedDoc doc) async {
    await _api.postMultipart(
      '/customers/$customerId/documents',
      fields: {'doc_type': docTypeWire},
      fileField: 'file',
      filename: doc.name,
      bytes: doc.bytes,
      mimeType: doc.mimeType ?? PickedDoc.mimeFor(doc.name),
    );
    await _reload(customerId);
  }

  @override
  Future<void> deleteDocument(String customerId, int docId) async {
    await _api.delete('/customers/documents/$docId');
    await _reload(customerId);
  }

  @override
  String documentUrl(int docId) =>
      _api.absoluteUrl('/customers/documents/$docId');

  @override
  Future<Uint8List> documentBytes(int docId) =>
      _api.getBytes('/customers/documents/$docId');

  @override
  void delete(String id) {
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
    _api.delete('/customers/$id').catchError((_) {});
  }

  @override
  void confirm(String id, String byUserId) {
    final c = byId(id);
    if (c == null) return;
    Gate.confirm(c, byUserId: byUserId); // optimistic local update
    notifyListeners();
    // by_user_id comes from the Bearer token server-side. Re-pull the server's
    // authoritative version so any details finalised on confirm show immediately.
    _api
        .post('/customers/$id/confirm')
        .then((_) => refresh())
        .catchError((_) => null);
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final c = byId(id);
    if (c == null) return;
    Gate.reject(c, reason: reason, byUserId: byUserId); // optimistic
    notifyListeners();
    // reason stays a query param; by_user_id comes from the Bearer token.
    _api.post('/customers/$id/reject',
            query: {'reason': reason})
        .then((_) => refresh())
        .catchError((_) => null);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<void> _reload(String customerId) async {
    final json = await _api.get('/customers/$customerId');
    _replaceInCache(_fromJson(json as Map<String, dynamic>));
    notifyListeners();
  }

  void _replaceInCache(Customer fresh) {
    final i = _customers.indexWhere((c) => c.id == fresh.id);
    if (i != -1) {
      _customers[i] = fresh;
    } else {
      _customers.insert(0, fresh);
    }
  }

  static String? _date(DateTime? d) => d?.toIso8601String().split('T').first;

  static DateTime? _parseDate(dynamic s) =>
      (s is String && s.isNotEmpty) ? DateTime.tryParse(s) : null;

  Customer _fromJson(Map<String, dynamic> j) {
    final docs = (j['documents'] as List?)
            ?.map((d) => DocRef.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return Customer(
      id: j['id'].toString(),
      firstName: (j['first_name'] as String?) ?? '',
      lastName: (j['last_name'] as String?) ?? '',
      phone: (j['phone'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      branch: j['branch'] != null ? Branch.fromWire(j['branch'] as String) : null,
      age: j['age'] as int?,
      dob: _parseDate(j['dob']),
      assurityName: j['assurity_name'] as String?,
      assurityMobile: j['assurity_mobile'] as String?,
      createdBy: j['created_by']?.toString() ?? '',
      createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
      status: EntityStatus.fromWire((j['status'] as String?) ?? 'active'),
      confirmedBy: j['confirmed_by']?.toString(),
      confirmedAt: _parseDate(j['confirmed_at']),
      rejectionReason: j['rejection_reason'] as String?,
      remarks: j['remarks'] as String?,
      uploadedDocs: docs,
    );
  }
}
