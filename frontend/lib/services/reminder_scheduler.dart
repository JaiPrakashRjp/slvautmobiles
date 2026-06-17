import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../utils/formatters.dart';
import 'loan_service.dart';
import 'rental_service.dart';
import 'sale_service.dart';

/// A computed reminder the daily cron (Phase 7 Cloud Function) would dispatch.
class ReminderHit {
  ReminderHit(this.kind, this.message);
  final String kind; // 'sale' | 'loan' | 'rental' | 'service'
  final String message;
}

/// Mock reminder engine. Mirrors the cron logic in spec 11.3 so the schedule is
/// testable now: sale installments at T-3/T-0/overdue, EMIs at T-5/T-0/overdue,
/// rentals per basis, and service-due (in-app) within 7 days. Logs to console.
class ReminderScheduler {
  const ReminderScheduler({
    required this.sales,
    required this.loans,
    required this.rentals,
  });

  final SaleService sales;
  final LoanService loans;
  final RentalService rentals;

  List<ReminderHit> run({required DateTime now}) {
    final hits = <ReminderHit>[];

    // Sale installments: T-3, T-0, and daily once overdue.
    for (final sale in sales.all().where((s) => s.saleStatus == 'active')) {
      for (final inst in sale.installments.where((i) => !i.isPaid)) {
        final days = Formatters.daysUntil(inst.dueDate, now: now);
        if (days == 3 || days == 0 || days < 0) {
          hits.add(ReminderHit(
            'sale',
            'Installment month ${inst.monthNumber} of ${Formatters.currency(inst.amount)} '
            '${days < 0 ? 'is ${-days} day(s) overdue' : 'due in $days day(s)'}',
          ));
        }
      }
    }

    // EMIs: T-5, T-0, and daily once overdue.
    for (final loan in loans.all().where((l) => !l.isClosed && l.isActive)) {
      for (final emi in loan.emis.where((e) => !e.isPaid)) {
        final days = Formatters.daysUntil(emi.dueDate, now: now);
        if (days == 5 || days == 0 || days < 0) {
          hits.add(ReminderHit(
            'loan',
            'EMI ${emi.sequenceNumber} of ${Formatters.currency(emi.amountDue)} '
            '${days < 0 ? 'is ${-days} day(s) overdue' : 'due in $days day(s)'}',
          ));
        }
      }
    }

    // Rentals: daily=morning of due day; weekly=T-1/T-0/overdue; monthly=T-3/T-0/overdue.
    for (final rental in rentals.activeRentals()) {
      for (final coll in rental.collections.where((c) => !c.isPaid)) {
        final days = Formatters.daysUntil(coll.dueDate, now: now);
        final fire = switch (rental.basis) {
          RentalBasis.daily => days <= 0,
          RentalBasis.weekly => days == 1 || days == 0 || days < 0,
          RentalBasis.monthly => days == 3 || days == 0 || days < 0,
        };
        if (fire) {
          hits.add(ReminderHit(
            'rental',
            'Rent of ${Formatters.currency(coll.amount)} '
            '${days < 0 ? 'is ${-days} day(s) overdue' : 'due in $days day(s)'}',
          ));
        }
      }
    }

    // Service due (in-app to SA/Admin only — never to renters).
    for (final v in rentals.serviceDueWithin(7, now: now)) {
      final days = Formatters.daysUntil(v.nextServiceDueDate!, now: now);
      hits.add(ReminderHit(
        'service',
        '${v.regNo} service ${days < 0 ? 'overdue by ${-days} day(s)' : 'due in $days day(s)'}',
      ));
    }

    if (kDebugMode) {
      debugPrint('[reminders] ${now.toIso8601String()} — ${hits.length} due:');
      for (final h in hits) {
        debugPrint('  • [${h.kind}] ${h.message}');
      }
    }
    return hits;
  }
}
