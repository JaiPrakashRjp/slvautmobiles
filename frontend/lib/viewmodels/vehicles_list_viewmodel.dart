import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

/// Backs the vehicles list: Assigned / Unassigned tabs, search, pagination,
/// and role-aware delete/approve actions.
class VehiclesListViewModel extends ChangeNotifier {
  VehiclesListViewModel(this._vehicles, this._auth) {
    // Pull fresh data when the list opens (shows the loading spinner).
    // Deferred so notifyListeners() doesn't fire during the widget build.
    Future.microtask(_vehicles.refresh);
  }

  final VehicleService _vehicles;
  final AuthController _auth;

  int _pageSize = 50;

  int _tab = 0; // 0 = Sold, 1 = Not sold
  int _page = 0;
  String _query = '';

  int get tab => _tab;
  int get page => _page;
  int get pageSize => _pageSize;
  String get query => _query;

  set pageSize(int v) {
    _pageSize = v;
    _page = 0;
    notifyListeners();
  }

  set tab(int v) {
    _tab = v;
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

  List<Vehicle> get _filtered {
    final base = _tab == 0 ? _vehicles.sold() : _vehicles.notSold();
    if (_query.isEmpty) return base;
    return base
        .where((v) =>
            v.regNo.toLowerCase().contains(_query) ||
            v.displayId.toLowerCase().contains(_query) ||
            (v.model ?? '').toLowerCase().contains(_query) ||
            (v.chassisNo ?? '').toLowerCase().contains(_query))
        .toList();
  }

  int get totalPages =>
      (_filtered.length / pageSize).ceil().clamp(1, 9999);

  List<Vehicle> get pageItems {
    final all = _filtered;
    final start = _page * pageSize;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + pageSize).clamp(0, all.length));
  }

  bool get isEmpty => _filtered.isEmpty;

  bool get canDelete => true; // both roles can request; gate applies on others

  void delete(String id) => _vehicles.delete(id);

  void approve(String id) =>
      _vehicles.confirm(id, _auth.currentUser?.id ?? 'u_super');
}
