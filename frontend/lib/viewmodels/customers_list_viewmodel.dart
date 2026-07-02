import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../services/vehicle_service.dart';

/// Backs the customers list: Assigned / Not Assigned tabs + role-aware actions.
/// A customer is "Assigned" when at least one vehicle is assigned to them.
class CustomersListViewModel extends ChangeNotifier {
  CustomersListViewModel(this._customers, this._vehicles, this._auth) {
    // Pull fresh data when the list opens (shows the loading spinner).
    // Deferred so notifyListeners() doesn't fire during the widget build.
    Future.microtask(() async {
      await _customers.refresh();
      await _vehicles.refresh();
    });
  }

  final CustomerService _customers;
  final VehicleService _vehicles;
  final AuthController _auth;

  int _tab = 0; // 0 = With vehicle (assigned), 1 = Without
  int _page = 0;
  int _pageSize = 50;
  String _query = '';

  int get tab => _tab;
  int get page => _page;
  int get pageSize => _pageSize;
  String get query => _query;

  set tab(int v) {
    _tab = v;
    _page = 0;
    notifyListeners();
  }

  set pageSize(int v) {
    _pageSize = v;
    _page = 0;
    notifyListeners();
  }

  void search(String q) {
    _query = q.trim().toLowerCase();
    _page = 0;
    notifyListeners();
  }

  void setPage(int p) {
    _page = p;
    notifyListeners();
  }

  Set<String> get _assignedIds => _vehicles
      .all()
      .where((v) => v.assignedToCustomerId != null)
      .map((v) => v.assignedToCustomerId!)
      .toSet();

  List<Customer> get _filtered {
    final assigned = _assignedIds;
    return _customers.all().where((c) {
      final isAssigned = assigned.contains(c.id);
      final tabOk = _tab == 0 ? isAssigned : !isAssigned;
      if (!tabOk) return false;
      if (_query.isEmpty) return true;
      return c.fullName.toLowerCase().contains(_query) ||
          c.phone.toLowerCase().contains(_query);
    }).toList();
  }

  int get totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 9999);

  List<Customer> get pageItems {
    final all = _filtered;
    final start = _page * _pageSize;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  bool isAssigned(Customer c) => _assignedIds.contains(c.id);

  bool get isEmpty => _filtered.isEmpty;

  void delete(String id) => _customers.delete(id);

  void approve(String id) =>
      _customers.confirm(id, _auth.currentUser?.id ?? 'u_super');
}
