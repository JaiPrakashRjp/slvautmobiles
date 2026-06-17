import 'enums.dart';
import 'gated_entity.dart';

/// A logged service for a vehicle. `nextServiceDueDate` is auto-set to
/// serviceDate + [intervalMonths] (default 3) on approval.
class ServiceRecord with GatedEntity {
  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    this.servicedBy,
    this.cost = 0,
    this.intervalMonths = 3,
    DateTime? nextServiceDueDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.status = EntityStatus.active,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
  }) : nextServiceDueDate = nextServiceDueDate ??
            DateTime(serviceDate.year, serviceDate.month + intervalMonths,
                serviceDate.day);

  @override
  final String id;
  final String vehicleId;
  DateTime serviceDate;
  String? servicedBy;
  int cost;
  int intervalMonths;
  DateTime nextServiceDueDate;
  String? notes;

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
}
