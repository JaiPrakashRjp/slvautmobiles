import '../models/search_result.dart';
import 'api_client.dart';

/// Calls the backend `/search` endpoint (min 4 chars, indexed / trigram).
class GlobalSearchService {
  GlobalSearchService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  static const int minChars = 4;

  Future<List<SearchResult>> search(String q) async {
    final term = q.trim();
    if (term.length < minChars) return [];
    final data = await _api.get('/search', query: {'q': term, 'limit': 20});
    return (data as List)
        .map((j) => SearchResult.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
