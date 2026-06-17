import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../services/vehicle_service.dart';

/// Backs the customers list: Assigned / Not Assigned tabs + role-aware actions.
/// A customer is "Assigned" when at least one vehicle is assigned to them.
class CustomersListViewModel extends ChangeNotifier {
  CustomersListViewModel(this._customers, this._vehicles, this._auth);

  final CustomerService _customers;
  final VehicleService _vehicles;
  final AuthController _auth;

  int _tab = 0; // 0 = Assigned, 1 = Not Assigned
  int get tab => _tab;
  set tab(int v) {
    _tab = v;
    notifyListeners();
  }

  Set<String> get _assignedIds => _vehicles
      .all()
      .where((v) => v.assignedToCustomerId != null)
      .map((v) => v.assignedToCustomerId!)
      .toSet();

  List<Customer> get items {
    final assigned = _assignedIds;
    return _customers.all().where((c) {
      final isAssigned = assigned.contains(c.id);
      return _tab == 0 ? isAssigned : !isAssigned;
    }).toList();
  }

  bool isAssigned(Customer c) => _assignedIds.contains(c.id);

  bool get isEmpty => items.isEmpty;

  void delete(String id) => _customers.delete(id);

  void approve(String id) =>
      _customers.confirm(id, _auth.currentUser?.id ?? 'u_super');
}
