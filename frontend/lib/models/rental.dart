import 'enums.dart';
import 'gated_entity.dart';
import 'rental_collection.dart';

/// A vehicle rented to a customer on a daily / weekly / monthly basis.
class Rental with GatedEntity {
  Rental({
    required this.id,
    required this.vehicleId,
    required this.customerId,
    required this.basis,
    required this.rent,
    this.securityDeposit = 0,
    required this.startDate,
    this.endDate,
    this.rentalStatus = 'active',
    List<RentalCollection>? collections,
    this.penaltyType = PenaltyType.flatPerDay,
    this.penaltyValue = 0,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
  }) : collections = collections ?? [];

  @override
  final String id;
  final String vehicleId;
  final String customerId;
  RentalBasis basis;
  int rent; // amount per cycle
  int securityDeposit;
  DateTime startDate;
  DateTime? endDate;

  /// 'active' | 'ended' | 'cancelled' | 'rejected'
  String rentalStatus;
  List<RentalCollection> collections;
  PenaltyType penaltyType;
  num penaltyValue;

  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  @override
  EntityStatus status;
  @override
  String? confirmedBy;
  @override
  DateTime? confirmedAt;
  @override
  String? rejectionReason;

  bool get isOngoing => rentalStatus == 'active';

  int get totalCollected =>
      collections.where((c) => c.isPaid).fold(0, (s, c) => s + c.amount);

  int get paidCycles => collections.where((c) => c.isPaid).length;

  /// The earliest unpaid collection's due date, or null if all paid.
  DateTime? get nextCollectionDue {
    final unpaid = collections.where((c) => !c.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaid.isEmpty ? null : unpaid.first.dueDate;
  }

  /// "On time" if no unpaid collection is past due, else the overdue cycle label.
  String dueLabel(DateTime now) {
    final overdue = collections.firstWhere(
      (c) => !c.isPaid && c.statusAt(now) == ScheduleStatus.overdue,
      orElse: () => RentalCollection(
          id: '', cycleNumber: -1, dueDate: now, amount: 0),
    );
    if (overdue.cycleNumber == -1) return 'On time';
    final unit = switch (basis) {
      RentalBasis.daily => 'Day',
      RentalBasis.weekly => 'Week',
      RentalBasis.monthly => 'Month',
    };
    return '$unit ${overdue.cycleNumber} due';
  }
}
