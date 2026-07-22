/// Aggregated data for the second-hand vehicles report over a period (a whole
/// month, or a custom From–To range). Built on the client from the loaded
/// vehicles + customers. Lists the second-hand vehicles BOUGHT in the period
/// (by purchase date).
class SecondHandReport {
  SecondHandReport({
    required this.from,
    required this.to,
    required this.label,
    required this.rows,
  });

  final DateTime from; // inclusive start of the period
  final DateTime to; // inclusive end of the period
  final String label; // e.g. "July 2026" or "01–15 Jul 2026"
  final List<SecondHandRow> rows;

  int get count => rows.length;
  int get totalBuying => rows.fold(0, (s, r) => s + r.buyingPrice);
  int get soldCount => rows.where((r) => r.sold).length;
  int get inStockCount => rows.where((r) => !r.sold).length;
}

class SecondHandRow {
  SecondHandRow({
    required this.purchaseDate,
    required this.vehicle,
    required this.model,
    required this.fuel,
    required this.prevOwnerName,
    required this.prevOwnerMobile,
    required this.buyingPrice,
    required this.sold,
    required this.buyerName,
    required this.buyerMobile,
  });

  final DateTime? purchaseDate;
  final String vehicle; // reg number, or chassis when unregistered
  final String model;
  final String fuel;
  final String prevOwnerName;
  final String prevOwnerMobile;
  final int buyingPrice; // buying expenses
  final bool sold;
  final String? buyerName; // current owner (customer), when sold
  final String? buyerMobile; // buyer's mobile, when sold
}
