import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import '../services/customer_service.dart';

/// Backs the create / edit customer form. Pass [existing] for edit mode
/// (fields pre-filled, submit() PATCHes; documents are managed live on screen).
class CreateCustomerViewModel extends ChangeNotifier {
  CreateCustomerViewModel(this._customers, this._auth, {Customer? existing})
      : _existing = existing {
    if (existing != null) _prefill(existing);
  }

  final CustomerService _customers;
  final AuthController _auth;
  final Customer? _existing;

  bool get isEditing => _existing != null;
  String? get existingId => _existing?.id;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();
  final addressController = TextEditingController();
  final assurityNameController = TextEditingController();
  final assurityMobileController = TextEditingController();
  final remarksController = TextEditingController();

  DateTime? _dob;
  Branch? _branch;

  /// New documents picked on the create form (uploaded after create). Unused in
  /// edit mode, where documents are managed live via the backend.
  final Map<KycDocType, PickedDoc> _docs = {};
  PickedDoc? _assurityIdProof;

  DateTime? get dob => _dob;
  Branch? get branch => _branch;
  Map<KycDocType, PickedDoc> get docs => _docs;
  PickedDoc? get assurityIdProof => _assurityIdProof;

  void _prefill(Customer c) {
    firstNameController.text = c.firstName;
    lastNameController.text = c.lastName;
    phoneController.text = c.phone;
    ageController.text = c.age?.toString() ?? '';
    addressController.text = c.address;
    assurityNameController.text = c.assurityName ?? '';
    assurityMobileController.text = c.assurityMobile ?? '';
    remarksController.text = c.remarks ?? '';
    _dob = c.dob;
    _branch = c.branch;
  }

  set dob(DateTime? v) {
    _dob = v;
    notifyListeners();
  }

  set branch(Branch? v) {
    _branch = v;
    notifyListeners();
  }

  void setDocument(KycDocType t, PickedDoc doc) {
    _docs[t] = doc;
    notifyListeners();
  }

  void removeDocument(KycDocType t) {
    _docs.remove(t);
    notifyListeners();
  }

  set assurityIdProof(PickedDoc? doc) {
    _assurityIdProof = doc;
    notifyListeners();
  }

  /// Creates or updates the customer. On create, uploads the picked documents.
  /// Returns whether the result is pending confirmation plus any docs that
  /// failed to upload. Throws if saving the record fails.
  Future<({bool pending, List<String> failedDocs})> submit() async {
    final user = _auth.currentUser!;
    final failedDocs = <String>[];

    if (isEditing) {
      await _customers.update(
        _existing!.id,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        branch: _branch,
        age: int.tryParse(ageController.text.trim()),
        dob: _dob,
        assurityName: assurityNameController.text.trim(),
        assurityMobile: assurityMobileController.text.trim(),
        remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
      );
      return (pending: false, failedDocs: failedDocs);
    }

    final customer = await _customers.create(
      actorRole: user.role,
      actorId: user.id,
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      phone: phoneController.text.trim(),
      address: addressController.text.trim(),
      branch: _branch,
      age: int.tryParse(ageController.text.trim()),
      dob: _dob,
      assurityName: assurityNameController.text.trim(),
      assurityMobile: assurityMobileController.text.trim(),
      remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
    );

    for (final entry in _docs.entries) {
      await _tryUpload(
          customer.id, entry.key.wire, entry.value, entry.key.label, failedDocs);
    }
    await _tryUpload(customer.id, 'assurity_id_proof', _assurityIdProof,
        'Assurity ID proof', failedDocs);

    return (pending: !user.isSuperAdmin, failedDocs: failedDocs);
  }

  Future<void> _tryUpload(String customerId, String docTypeWire, PickedDoc? doc,
      String label, List<String> failedDocs) async {
    if (doc == null) return;
    try {
      await _customers.uploadDocument(customerId, docTypeWire, doc);
    } catch (_) {
      failedDocs.add(label);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    addressController.dispose();
    assurityNameController.dispose();
    assurityMobileController.dispose();
    remarksController.dispose();
    super.dispose();
  }
}
