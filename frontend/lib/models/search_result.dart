/// A vehicle a customer bought — nested under a customer search result.
class SearchVehicle {
  SearchVehicle({required this.id, required this.label, this.subtitle = ''});

  final int id;
  final String label;
  final String subtitle;

  factory SearchVehicle.fromJson(Map<String, dynamic> j) => SearchVehicle(
        id: j['id'] as int,
        label: j['label'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
      );
}

/// One global-search hit (a customer or a vehicle).
class SearchResult {
  SearchResult({
    required this.kind,
    required this.id,
    required this.label,
    this.subtitle = '',
    this.module = 'auto_sale',
    this.vehicles = const [],
  });

  final String kind; // 'customer' | 'vehicle'
  final int id;
  final String label;
  final String subtitle;
  final String module;

  /// For customer results: every vehicle sold to them (may be more than one).
  final List<SearchVehicle> vehicles;

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        kind: j['kind'] as String,
        id: j['id'] as int,
        label: j['label'] as String,
        subtitle: (j['subtitle'] as String?) ?? '',
        module: (j['module'] as String?) ?? 'auto_sale',
        vehicles: (j['vehicles'] as List?)
                ?.map((v) => SearchVehicle.fromJson(v as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
