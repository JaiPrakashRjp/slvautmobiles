import 'package:flutter/foundation.dart';

import '../models/financer.dart';

/// Sale financers — the finance companies used for SALE finance. A completely
/// separate master list from vehicle financers ([FinancerService]).
abstract class SaleFinancerService extends ChangeNotifier {
  List<Financer> all();
  Financer? byId(int id);

  Future<void> refresh() async {}
  Future<Financer> create(String name);
  Future<void> delete(int id);
}

class MockSaleFinancerService extends SaleFinancerService {
  final List<Financer> _financers = [
    Financer(id: 1, name: 'Shriram Finance'),
    Financer(id: 2, name: 'Cholamandalam'),
  ];

  @override
  List<Financer> all() => List.unmodifiable(_financers);

  @override
  Financer? byId(int id) =>
      _financers.where((f) => f.id == id).cast<Financer?>().firstOrNull;

  @override
  Future<Financer> create(String name) async {
    final id = (_financers.isEmpty ? 0 : _financers.last.id) + 1;
    final f = Financer(id: id, name: name.trim());
    _financers.add(f);
    notifyListeners();
    return f;
  }

  @override
  Future<void> delete(int id) async {
    _financers.removeWhere((f) => f.id == id);
    notifyListeners();
  }
}
