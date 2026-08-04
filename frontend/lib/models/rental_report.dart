import 'monthly_report.dart' show MonthlyVehicleRow;

export 'monthly_report.dart' show MonthlyVehicleRow;

/// Aggregated rental data for the report PDF over a month / custom range. Built
/// on the client from the loaded rentals / vehicles / customers. Unlike the sale
/// report, recurring rentals have no fixed total or outstanding balance, so this
/// centres on rent COLLECTED in the period and a Weekly/Daily split.
class RentalReport {
  RentalReport({
    required this.from,
    required this.to,
    required this.label,
    required this.rentals,
    required this.collections,
    required this.idle,
    required this.newCustomerCount,
  });

  final DateTime from; // inclusive start of the period
  final DateTime to; // inclusive end of the period
  final String label; // e.g. "July 2026" or "01–15 Jul 2026"
  final List<RentalReportRow> rentals; // rentals STARTED in the period
  final List<RentalCollectionRow> collections; // rent collected in the period
  final List<MonthlyVehicleRow> idle; // current idle (not-rented) vehicles
  final int newCustomerCount; // customers added in the period

  int get rentalCount => rentals.length;
  int get weeklyCount => rentals.where((r) => r.type == 'weekly').length;
  int get dailyCount => rentals.where((r) => r.type == 'daily').length;
  int get collectedTotal => collections.fold(0, (s, e) => s + e.amount);
}

class RentalReportRow {
  RentalReportRow({
    required this.date,
    required this.customerName,
    required this.vehicle,
    required this.type,
    required this.rent,
    required this.collected,
  });

  final DateTime date; // rental start date
  final String customerName;
  final String vehicle;
  final String type; // 'weekly' | 'daily' | '' (legacy)
  final int rent; // per-period rent
  final int collected; // rent collected in the period for this rental
}

class RentalCollectionRow {
  RentalCollectionRow({
    required this.date,
    required this.customerName,
    required this.vehicle,
    required this.amount,
  });

  final DateTime date; // payment paid-on date
  final String customerName;
  final String vehicle;
  final int amount;
}
