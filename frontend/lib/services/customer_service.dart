import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/doc_ref.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import '../utils/id_gen.dart';
import 'gate.dart';

/// Customer data access. Abstract so the real backend implementation
/// (ApiCustomerService) can drop in without touching view models.
abstract class CustomerService extends ChangeNotifier {
  List<Customer> all();
  Customer? byId(String id);

  /// Loads customers from the backing store (no-op for the in-memory mock).
  Future<void> refresh() async {}

  Future<Customer> create({
    required Role actorRole,
    required String actorId,
    required String firstName,
    String lastName,
    required String phone,
    String address,
    Branch? branch,
    int? age,
    DateTime? dob,
    String? assurityName,
    String? assurityMobile,
  });

  /// Edits an existing customer (PATCH). Only non-null fields are changed.
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
  });

  /// Uploads one KYC file (upsert by doc type). [docTypeWire] is the backend
  /// `kyc_doc_type` value (e.g. `aadhaar`, `assurity_id_proof`).
  Future<void> uploadDocument(String customerId, String docTypeWire, PickedDoc doc);

  /// Deletes a stored document by its backend id.
  Future<void> deleteDocument(String customerId, int docId);

  /// Absolute URL to download/view a stored document (empty for the mock).
  String documentUrl(int docId);

  /// Raw bytes of a stored document, for in-app preview.
  Future<Uint8List> documentBytes(int docId);

  void delete(String id);
  void confirm(String id, String byUserId);
  void reject(String id, String reason, String byUserId);
}

class MockCustomerService extends CustomerService {
  MockCustomerService() {
    _seed();
  }

  final List<Customer> _customers = [];

  void _seed() {
    IdGen.seedAtLeast('c', 2);
    _customers.addAll([
      Customer(
        id: 'c_001',
        firstName: 'Ravi',
        lastName: 'Kumar',
        phone: '+919876543210',
        address: '123 MG Road, Bengaluru',
        age: 32,
        dob: DateTime(1993, 5, 12),
        createdBy: 'u_super',
        createdAt: DateTime(2026, 3, 2),
        status: EntityStatus.active,
      ),
      Customer(
        id: 'c_002',
        firstName: 'Suresh',
        lastName: 'Babu',
        phone: '+919845012345',
        address: '7 Jayanagar 4th Block, Bengaluru',
        age: 41,
        createdBy: 'u_admin_ravi',
        createdAt: DateTime(2026, 5, 28),
        status: EntityStatus.pendingConfirmation,
      ),
    ]);
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
  }) async {
    final customer = Customer(
      id: IdGen.nextId('c'),
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address: address,
      branch: branch,
      age: age,
      dob: dob,
      assurityName: assurityName,
      assurityMobile: assurityMobile,
      createdBy: actorId,
      createdAt: DateTime.now(),
      status: Gate.initialStatus(actorRole),
    );
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
  }) async {
    final c = byId(id)!;
    if (firstName != null) c.firstName = firstName;
    if (lastName != null) c.lastName = lastName;
    if (phone != null) c.phone = phone;
    if (address != null) c.address = address;
    if (branch != null) c.branch = branch;
    if (age != null) c.age = age;
    if (dob != null) c.dob = dob;
    if (assurityName != null) c.assurityName = assurityName;
    if (assurityMobile != null) c.assurityMobile = assurityMobile;
    if (status != null) c.status = status;
    notifyListeners();
    return c;
  }

  int _mockDocId = 0;

  @override
  Future<void> uploadDocument(
      String customerId, String docTypeWire, PickedDoc doc) async {
    final c = byId(customerId);
    if (c == null) return;
    c.uploadedDocs.removeWhere((d) => d.docTypeWire == docTypeWire);
    c.uploadedDocs.add(
      DocRef(id: ++_mockDocId, docTypeWire: docTypeWire, fileName: doc.name),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteDocument(String customerId, int docId) async {
    final c = byId(customerId);
    if (c == null) return;
    c.uploadedDocs.removeWhere((d) => d.id == docId);
    notifyListeners();
  }

  @override
  String documentUrl(int docId) => '';

  @override
  Future<Uint8List> documentBytes(int docId) async => Uint8List(0);

  @override
  void delete(String id) {
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  @override
  void confirm(String id, String byUserId) {
    final c = byId(id);
    if (c != null) {
      Gate.confirm(c, byUserId: byUserId);
      notifyListeners();
    }
  }

  @override
  void reject(String id, String reason, String byUserId) {
    final c = byId(id);
    if (c != null) {
      Gate.reject(c, reason: reason, byUserId: byUserId);
      notifyListeners();
    }
  }
}
