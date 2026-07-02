/// One global-search hit (a customer or a vehicle).
class SearchResult {
  SearchResult({
    required this.kind,
    required this.id,
    required this.label,
    this.subtitle = '',
    this.module = 'auto_sale',
  });

  final String kind; // 'customer' | 'vehicle'
  final int id;
  final String label;
  final String subtitle;
  final String module;

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        kind: j['kind'] as String,
        id: j['id'] as int,
        label: j['label'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        module: (j['module'] as String?) ?? 'auto_sale',
      );
}
