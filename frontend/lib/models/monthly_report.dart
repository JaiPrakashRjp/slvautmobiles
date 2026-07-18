/// Aggregated data for the report PDF over a date range (a whole month, or a
/// custom From–To range). Built on the client from the already-loaded sales /
/// vehicles / customers.
class MonthlyReport {
  MonthlyReport({
    required this.from,
    required this.to,
    required this.label,
    required this.sales,
    required this.unsold,
    required this.newCustomerCount,
  });

  final DateTime from; // inclusive start of the period
  final DateTime to; // inclusive end of the period
  final String label; // e.g. "July 2026" or "01–15 Jul 2026"
  final List<MonthlySaleRow> sales; // sales made in the period
  final List<MonthlyVehicleRow> unsold; // current unsold inventory
  final int newCustomerCount; // customers added in the period

  int get soldCount => sales.length;
  int get soldValue => sales.fold(0, (s, e) => s + e.price);
  int get collected => sales.fold(0, (s, e) => s + e.received);
  int get outstanding => sales.fold(0, (s, e) => s + e.balance);

  /// Period sales that still owe money.
  List<MonthlySaleRow> get dues => sales.where((s) => s.balance > 0).toList();
}

class MonthlySaleRow {
  MonthlySaleRow({
    required this.date,
    required this.customerName,
    required this.phone,
    required this.vehicle,
    required this.price,
    required this.received,
    required this.balance,
  });

  final DateTime date;
  final String customerName;
  final String phone;
  final String vehicle;
  final int price;
  final int received;
  final int balance;
}

class MonthlyVehicleRow {
  MonthlyVehicleRow({
    required this.identifier,
    required this.model,
    required this.type,
    this.purchaseDate,
  });

  final String identifier; // reg no or chassis
  final String model;
  final String type;
  final DateTime? purchaseDate;
}
