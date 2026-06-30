import '../models/financer.dart';
import 'api_client.dart';
import 'sale_financer_service.dart';

/// Real [SaleFinancerService] backed by the `/sale-financers` API.
class ApiSaleFinancerService extends SaleFinancerService {
  ApiSaleFinancerService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;
  final List<Financer> _financers = [];

  @override
  Future<void> refresh() async {
    final data = await _api.get('/sale-financers');
    _financers
      ..clear()
      ..addAll((data as List).map((j) => _fromJson(j as Map<String, dynamic>)));
    notifyListeners();
  }

  @override
  List<Financer> all() => List.unmodifiable(_financers);

  @override
  Financer? byId(int id) =>
      _financers.where((f) => f.id == id).cast<Financer?>().firstOrNull;

  @override
  Future<Financer> create(String name) async {
    final j = await _api.post('/sale-financers', body: {'name': name.trim()});
    final financer = _fromJson(j as Map<String, dynamic>);
    _financers.add(financer);
    _financers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return financer;
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete('/sale-financers/$id');
    _financers.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  Financer _fromJson(Map<String, dynamic> j) =>
      Financer(id: j['id'] as int, name: j['name'] as String);
}
