import '../models/enums.dart';
import '../models/gated_entity.dart';

/// Central role-gate helper (Section 5). A Super Admin's action takes effect
/// immediately (`active`); an Admin's action is held `pending_confirmation`
/// until the Super Admin confirms or rejects it.
class Gate {
  const Gate._();

  static EntityStatus initialStatus(Role actor) => actor == Role.superAdmin
      ? EntityStatus.active
      : EntityStatus.pendingConfirmation;

  /// Confirms a pending entity in place.
  static void confirm(GatedEntity e, {required String byUserId, DateTime? now}) {
    e.status = EntityStatus.active;
    e.confirmedBy = byUserId;
    e.confirmedAt = now ?? DateTime.now();
    e.rejectionReason = null;
  }

  /// Rejects a pending entity in place with a reason.
  static void reject(GatedEntity e, {required String reason, required String byUserId}) {
    e.status = EntityStatus.rejected;
    e.confirmedBy = byUserId;
    e.rejectionReason = reason;
  }
}
