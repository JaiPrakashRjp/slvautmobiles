import 'enums.dart';

/// Mixin carrying the role-gate contract every gated entity needs
/// (Section 5.2). `id`/`createdBy`/`createdAt` are immutable getters; the
/// status fields are abstract (getter+setter) so the gate service can flip
/// them in place on confirm/reject.
mixin GatedEntity {
  String get id;
  String get createdBy;
  DateTime get createdAt;

  abstract EntityStatus status;
  abstract String? confirmedBy;
  abstract DateTime? confirmedAt;
  abstract String? rejectionReason;

  bool get isPending => status == EntityStatus.pendingConfirmation;
  bool get isActive => status == EntityStatus.active;
  bool get isRejected => status == EntityStatus.rejected;
}
