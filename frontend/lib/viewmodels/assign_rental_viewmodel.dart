import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../models/enums.dart';
import '../models/vehicle.dart';
import '../services/rental_service.dart';

/// Backs the assign-rental form (mockup 12).
class AssignRentalViewModel extends ChangeNotifier {
  AssignRentalViewModel({
    String? customerId,
    required RentalService rentals,
    required AuthController auth,
  })  : _customerId = customerId,
        _rentals = rentals,
        _auth = auth;

  final RentalService _rentals;
  final AuthController _auth;

  String? _customerId;
  String? _vehicleId;
  RentalBasis _basis = RentalBasis.weekly;
  DateTime? _startDate;

  final rentController = TextEditingController(text: '2000');
  final depositController = TextEditingController();

  String? get customerId => _customerId;
  String? get vehicleId => _vehicleId;
  RentalBasis get basis => _basis;
  DateTime? get startDate => _startDate;

  /// True when the screen must show a renter picker (no customer pre-selected).
  bool get needsRenterPick => _customerId == null;

  List<Customer> get renters => _rentals.verifiedRenters();
  List<Vehicle> get availableVehicles => _rentals.availableVehicles();

  Customer? get customer =>
      _customerId == null ? null : _rentals.renterById(_customerId!);
  Vehicle? get selectedVehicle =>
      _vehicleId == null ? null : _rentals.vehicleById(_vehicleId!);

  /// "Weekly rent" / "Daily rent" / "Monthly rent".
  String get rentLabel => '${_basis.label} rent';
  String get rentSuffix => switch (_basis) {
        RentalBasis.daily => 'per day',
        RentalBasis.weekly => 'per week',
        RentalBasis.monthly => 'per month',
      };

  set customerId(String? v) {
    _customerId = v;
    notifyListeners();
  }

  set vehicleId(String? v) {
    _vehicleId = v;
    notifyListeners();
  }

  set basis(RentalBasis v) {
    _basis = v;
    notifyListeners();
  }

  set startDate(DateTime? v) {
    _startDate = v;
    notifyListeners();
  }

  String? validate() {
    if (_customerId == null) return 'Please select a renter';
    if (_vehicleId == null) return 'Please select a vehicle';
    if ((int.tryParse(rentController.text.trim()) ?? 0) <= 0) {
      return 'Enter the rent amount';
    }
    if (_startDate == null) return 'Pick the start date';
    return null;
  }

  bool submit() {
    final user = _auth.currentUser!;
    _rentals.createRental(
      actorRole: user.role,
      actorId: user.id,
      vehicleId: _vehicleId!,
      customerId: _customerId!,
      basis: _basis,
      rent: int.tryParse(rentController.text.trim()) ?? 0,
      securityDeposit: int.tryParse(depositController.text.trim()) ?? 0,
      startDate: _startDate!,
    );
    return !user.isSuperAdmin;
  }

  @override
  void dispose() {
    rentController.dispose();
    depositController.dispose();
    super.dispose();
  }
}
