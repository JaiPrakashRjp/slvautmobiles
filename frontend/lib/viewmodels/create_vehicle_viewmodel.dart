import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/enums.dart';
import '../models/picked_doc.dart';
import '../models/vehicle.dart';
import '../services/gate.dart';
import '../services/vehicle_service.dart';

/// Backs the create-vehicle form. The "Owned hand" choice is made first and the
/// rest of the form (common + first-hand / second-hand groups) appears once it
/// is selected. See the vehicle-form spec. When [existing] is passed the form
/// is in EDIT mode: fields are pre-filled and submit() PATCHes instead.
class CreateVehicleViewModel extends ChangeNotifier {
  CreateVehicleViewModel(this._vehicles, this._auth, {Vehicle? existing})
      : _existing = existing {
    if (existing != null) {
      _prefill(existing);
    } else {
      _status = Gate.initialStatus(_auth.currentUser?.role ?? Role.admin);
    }
  }

  final VehicleService _vehicles;
  final AuthController _auth;
  final Vehicle? _existing;

  bool get isEditing => _existing != null;

  // ── Common fields (both hand types) ──────────────────────────────────────
  final chassisController = TextEditingController();
  final modelController = TextEditingController();
  final buyingExpensesController = TextEditingController();
  final remarksController = TextEditingController();

  VehicleType? _hand; // null until the user picks Owned hand
  Branch? _branch;
  DateTime? _purchaseDate;
  FuelType? _fuelType;
  late EntityStatus _status; // Verified (active) / Not verified (pending)
  SaleStatus _saleStatus = SaleStatus.notSold; // editable in edit mode

  // ── Financer (optional, both hand types) ─────────────────────────────────
  int? _financerId;

  // ── First-hand only ──────────────────────────────────────────────────────
  Showroom? _showroom;

  // ── RC / Permit / Insurance (both hand types) ────────────────────────────
  bool _rc = false;
  bool _permit = false;
  bool _insurance = false;

  // ── Second-hand only ─────────────────────────────────────────────────────
  final regNoController = TextEditingController();
  final prevOwnerNameController = TextEditingController();
  final prevOwnerMobileController = TextEditingController();
  final prevOwnerAddressController = TextEditingController();

  /// Uploaded documents: doc type → picked file (bytes held for upload).
  final Map<VehicleDocType, PickedDoc> _documents = {};
  DateTime? _insuranceDate;
  DateTime? _fcDate;
  DateTime? _permitDate;
  PickedDoc? _prevOwnerIdProof; // picked file, null = not attached
  PickedDoc? _prevOwnerPhoto;

  // ── Getters ──────────────────────────────────────────────────────────────
  int? get financerId => _financerId;

  VehicleType? get hand => _hand;
  Branch? get branch => _branch;
  DateTime? get purchaseDate => _purchaseDate;
  FuelType? get fuelType => _fuelType;
  EntityStatus get status => _status;
  SaleStatus get saleStatus => _saleStatus;
  Showroom? get showroom => _showroom;
  bool get rc => _rc;
  bool get permit => _permit;
  bool get insurance => _insurance;
  Map<VehicleDocType, PickedDoc> get documents => _documents;
  DateTime? get insuranceDate => _insuranceDate;
  DateTime? get fcDate => _fcDate;
  DateTime? get permitDate => _permitDate;
  PickedDoc? get prevOwnerIdProof => _prevOwnerIdProof;
  PickedDoc? get prevOwnerPhoto => _prevOwnerPhoto;

  bool get isFirstHand => _hand == VehicleType.firstHand;
  bool get isSecondHand => _hand == VehicleType.secondHand;

  // ── Setters ──────────────────────────────────────────────────────────────
  set financerId(int? v) {
    _financerId = v;
    notifyListeners();
  }

  set hand(VehicleType? v) {
    _hand = v;
    notifyListeners();
  }

  set branch(Branch? v) {
    _branch = v;
    notifyListeners();
  }

  set purchaseDate(DateTime? v) {
    _purchaseDate = v;
    notifyListeners();
  }

  set fuelType(FuelType? v) {
    _fuelType = v;
    notifyListeners();
  }

  set status(EntityStatus v) {
    _status = v;
    notifyListeners();
  }

  set saleStatus(SaleStatus v) {
    _saleStatus = v;
    notifyListeners();
  }

  set showroom(Showroom? v) {
    _showroom = v;
    notifyListeners();
  }

  set rc(bool v) {
    _rc = v;
    notifyListeners();
  }

  set permit(bool v) {
    _permit = v;
    notifyListeners();
  }

  set insurance(bool v) {
    _insurance = v;
    notifyListeners();
  }

  set insuranceDate(DateTime? v) {
    _insuranceDate = v;
    notifyListeners();
  }

  set fcDate(DateTime? v) {
    _fcDate = v;
    notifyListeners();
  }

  set permitDate(DateTime? v) {
    _permitDate = v;
    notifyListeners();
  }

  /// Records an uploaded / captured file for a document type.
  void setDocument(VehicleDocType t, PickedDoc doc) {
    _documents[t] = doc;
    notifyListeners();
  }

  void removeDocument(VehicleDocType t) {
    _documents.remove(t);
    notifyListeners();
  }

  set prevOwnerIdProof(PickedDoc? doc) {
    _prevOwnerIdProof = doc;
    notifyListeners();
  }

  set prevOwnerPhoto(PickedDoc? doc) {
    _prevOwnerPhoto = doc;
    notifyListeners();
  }

  num? _parseAmount(String s) =>
      num.tryParse(s.replaceAll(RegExp(r'[,\s₹]'), ''));

  void _prefill(Vehicle v) {
    _hand = v.type;
    _branch = v.branch;
    chassisController.text = v.chassisNo ?? '';
    modelController.text = v.model ?? '';
    buyingExpensesController.text =
        v.buyingExpenses != null ? '${v.buyingExpenses}' : '';
    _fuelType = v.fuelType;
    _purchaseDate = v.purchaseDate;
    _financerId = v.financerId;
    _showroom = v.showroom;
    _rc = v.rc;
    _permit = v.permit;
    _insurance = v.insurance;
    _status = v.status;
    _saleStatus = v.saleStatus;
    regNoController.text = v.regNo;
    _insuranceDate = v.insuranceDate;
    _fcDate = v.fcDate;
    _permitDate = v.permitDate;
    prevOwnerNameController.text = v.prevOwnerName ?? '';
    prevOwnerMobileController.text = v.prevOwnerMobile ?? '';
    prevOwnerAddressController.text = v.prevOwnerAddress ?? '';
    remarksController.text = v.remarks ?? '';
  }

  /// Creates (or, in edit mode, updates) the vehicle, then uploads any newly
  /// attached documents. Returns whether the result is "Not verified"
  /// (`pending`) plus the labels of any documents that failed to upload (the
  /// record itself is still saved). Throws if saving the record fails.
  Future<({bool pending, List<String> failedDocs})> submit() async {
    final String vehicleId;
    if (isEditing) {
      final v = await _vehicles.update(
        _existing!.id,
        type: _hand,
        branch: _branch,
        regNo: regNoController.text.trim().toUpperCase(),
        chassisNo: chassisController.text.trim(),
        model: modelController.text.trim(),
        fuelType: _fuelType,
        buyingExpenses: _parseAmount(buyingExpensesController.text),
        showroom: isFirstHand ? _showroom : null,
        rc: _rc,
        permit: _permit,
        insurance: _insurance,
        insuranceDate: isSecondHand ? _insuranceDate : null,
        fcDate: isSecondHand ? _fcDate : null,
        permitDate: isSecondHand ? _permitDate : null,
        prevOwnerName: isSecondHand ? prevOwnerNameController.text.trim() : null,
        prevOwnerMobile:
            isSecondHand ? prevOwnerMobileController.text.trim() : null,
        prevOwnerAddress:
            isSecondHand ? prevOwnerAddressController.text.trim() : null,
        saleStatus: _saleStatus,
        status: _status,
        remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
        financerId: _financerId,
      );
      vehicleId = v.id;
    } else {
      final user = _auth.currentUser!;
      final v = await _vehicles.create(
        actorRole: user.role,
        actorId: user.id,
        type: _hand!,
        branch: _branch,
        regNo: regNoController.text.trim().toUpperCase(),
        chassisNo: chassisController.text.trim(),
        model: modelController.text.trim(),
        fuelType: _fuelType,
        purchaseDate: _purchaseDate,
        buyingExpenses: _parseAmount(buyingExpensesController.text),
        showroom: isFirstHand ? _showroom : null,
        rc: _rc,
        permit: _permit,
        insurance: _insurance,
        insuranceDate: isSecondHand ? _insuranceDate : null,
        fcDate: isSecondHand ? _fcDate : null,
        permitDate: isSecondHand ? _permitDate : null,
        prevOwnerName: isSecondHand ? prevOwnerNameController.text.trim() : null,
        prevOwnerMobile:
            isSecondHand ? prevOwnerMobileController.text.trim() : null,
        prevOwnerAddress:
            isSecondHand ? prevOwnerAddressController.text.trim() : null,
        status: _status,
        remarks: remarksController.text.trim().isEmpty ? null : remarksController.text.trim(),
        financerId: _financerId,
      );
      vehicleId = v.id;
    }

    final failedDocs = <String>[];
    // RC / Permit / Insurance documents apply to both hand types.
    await _tryUpload(vehicleId, VehicleDocType.rc.wire,
        _documents[VehicleDocType.rc], VehicleDocType.rc.label, failedDocs);
    await _tryUpload(vehicleId, VehicleDocType.permit.wire,
        _documents[VehicleDocType.permit], VehicleDocType.permit.label, failedDocs);
    await _tryUpload(vehicleId, VehicleDocType.insurance.wire,
        _documents[VehicleDocType.insurance], VehicleDocType.insurance.label,
        failedDocs);
    if (isSecondHand) {
      for (final entry in _documents.entries) {
        // rc / permit / insurance already handled above (both hands)
        if (entry.key == VehicleDocType.rc ||
            entry.key == VehicleDocType.permit ||
            entry.key == VehicleDocType.insurance) {
          continue;
        }
        await _tryUpload(
            vehicleId, entry.key.wire, entry.value, entry.key.label, failedDocs);
      }
      await _tryUpload(vehicleId, 'prev_owner_id_proof', _prevOwnerIdProof,
          'Previous owner ID proof', failedDocs);
      await _tryUpload(vehicleId, 'prev_owner_photo', _prevOwnerPhoto,
          'Previous owner photo', failedDocs);
    }

    return (pending: _status != EntityStatus.active, failedDocs: failedDocs);
  }

  Future<void> _tryUpload(String vehicleId, String docTypeWire, PickedDoc? doc,
      String label, List<String> failedDocs) async {
    if (doc == null) return;
    try {
      await _vehicles.uploadDocument(vehicleId, docTypeWire, doc);
    } catch (_) {
      failedDocs.add(label);
    }
  }

  @override
  void dispose() {
    chassisController.dispose();
    modelController.dispose();
    buyingExpensesController.dispose();
    regNoController.dispose();
    prevOwnerNameController.dispose();
    prevOwnerMobileController.dispose();
    prevOwnerAddressController.dispose();
    remarksController.dispose();
    super.dispose();
  }
}
