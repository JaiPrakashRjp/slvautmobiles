import 'package:flutter/foundation.dart';

import '../models/financer.dart';
import 'api_client.dart';

/// Financer master scoped to the **personal loan** module — its own list,
/// separate from the vehicle and sale financers (bifurcated per module).
class PersonalLoanFinancerService extends ChangeNotifier {
  PersonalLoanFinancerService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<Financer> _financers = [];

  List<Financer> all() => List.unmodifiable(_financers);

  Financer? byId(int id) =>
      _financers.where((f) => f.id == id).cast<Financer?>().firstOrNull;

  Future<void> refresh() async {
    try {
      final data = await _api.get('/personal-loans/financers');
      final fresh = (data as List)
          .map((j) => Financer(
                id: (j['id'] as num).toInt(),
                name: (j['name'] as String?) ?? '',
              ))
          .toList();
      _financers
        ..clear()
        ..addAll(fresh);
    } catch (_) {
      // keep cache
    }
    notifyListeners();
  }

  Future<Financer> create(String name) async {
    final json = await _api.post('/personal-loans/financers',
        body: {'name': name.trim()});
    final f = Financer(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? name.trim(),
    );
    _financers.add(f);
    notifyListeners();
    return f;
  }
}
