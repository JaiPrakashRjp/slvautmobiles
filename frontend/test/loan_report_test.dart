import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:slv_auto_consultant/models/emi.dart';
import 'package:slv_auto_consultant/models/enums.dart';
import 'package:slv_auto_consultant/models/loan.dart';
import 'package:slv_auto_consultant/models/loan_report.dart';
import 'package:slv_auto_consultant/services/pdf_service.dart';

/// Exercises the loan Daily + Monthly report aggregation with a realistic mix
/// of loans (paid / partial / booked-this-period / seized / rejected) and
/// renders the monthly-report PDF to disk for a visual check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Emi emi(int n, DateTime due, int amount, {int paid = 0, DateTime? received}) =>
      Emi(
        id: 'e$n-${due.millisecondsSinceEpoch}',
        sequenceNumber: n,
        dueDate: due,
        amountDue: amount,
        amountPaid: paid,
        receivedDate: received,
        paidDate: paid >= amount ? received : null,
      );

  Loan loan({
    required String id,
    required String cust,
    String? veh,
    required int principal,
    required int tenure,
    required int emiAmt,
    required DateTime disb,
    required List<Emi> emis,
    String status = 'active',
    String? seizeStage,
    EntityStatus entity = EntityStatus.active,
  }) =>
      Loan(
        id: id,
        customerId: cust,
        vehicleId: veh,
        principal: principal,
        tenureMonths: tenure,
        disbursementDate: disb,
        firstEmiDueDate: emis.first.dueDate,
        emiAmount: emiAmt,
        emis: emis,
        loanStatus: status,
        seizeStage: seizeStage,
        createdBy: 'u1',
        createdAt: disb,
        status: entity,
      );

  // ── Sample book (period under test = September 2026) ──────────────────────
  final loanA = loan(
    id: 'A', cust: 'c1', veh: 'v1', principal: 140000, tenure: 20, emiAmt: 7000,
    disb: DateTime(2026, 8, 5),
    emis: [
      emi(1, DateTime(2026, 9, 5), 7000, paid: 7000, received: DateTime(2026, 9, 6)),
      emi(2, DateTime(2026, 10, 5), 7000),
    ],
  );
  final loanB = loan(
    id: 'B', cust: 'c2', veh: 'v2', principal: 90000, tenure: 12, emiAmt: 8000,
    disb: DateTime(2026, 9, 10),
    emis: [emi(1, DateTime(2026, 10, 10), 8000)],
  );
  final loanC = loan(
    id: 'C', cust: 'c3', veh: 'v3', principal: 50000, tenure: 10, emiAmt: 5000,
    disb: DateTime(2026, 8, 15),
    emis: [
      emi(1, DateTime(2026, 9, 15), 5000, paid: 2000, received: DateTime(2026, 9, 20)),
    ],
  );
  final loanD = loan( // seized — excluded everywhere
    id: 'D', cust: 'c4', veh: 'v4', principal: 60000, tenure: 10, emiAmt: 6000,
    disb: DateTime(2026, 9, 1), status: 'seized', seizeStage: 'seized',
    emis: [emi(1, DateTime(2026, 9, 5), 6000)],
  );
  final loanE = loan( // rejected — excluded everywhere
    id: 'E', cust: 'c5', veh: 'v5', principal: 30000, tenure: 6, emiAmt: 5000,
    disb: DateTime(2026, 9, 3), status: 'rejected',
    emis: [emi(1, DateTime(2026, 9, 3), 5000)],
  );

  final loans = [loanA, loanB, loanC, loanD, loanE];

  final names = {'c1': 'Ravi Kumar', 'c2': 'Anita S', 'c3': 'Mahesh P',
    'c4': 'Suresh V', 'c5': 'Devi R'};
  final vehicles = {'v1': 'KA01AB1234', 'v2': 'KA02CD5678', 'v3': 'KA03EF9012',
    'v4': 'KA04GH3456', 'v5': 'KA05IJ7890'};

  LoanReport buildSept() => LoanReport.build(
        loans: loans,
        customerCreatedAt: [DateTime(2026, 9, 2), DateTime(2026, 8, 20)],
        customerName: (id) => names[id] ?? 'Customer',
        vehicleLabel: (id) => vehicles[id] ?? '—',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        label: 'September 2026',
      );

  group('LoanReport.build (monthly)', () {
    final r = buildSept();

    test('loans booked in the period', () {
      expect(r.loanCount, 1); // only Loan B disbursed in Sept
      expect(r.loans.single.customerName, 'Anita S');
      expect(r.disbursedTotal, 90000);
    });

    test('EMI collected in the period', () {
      expect(r.collections.length, 2); // A#1 (7000) + C#1 (2000)
      expect(r.collectedTotal, 9000);
    });

    test('EMIs due in the period, with status', () {
      expect(r.dueCount, 2); // A#1 + C#1 (B due Oct, D/E excluded)
      final byCust = {for (final d in r.dues) d.customerName: d.status};
      expect(byCust['Ravi Kumar'], 'Paid');
      expect(byCust['Mahesh P'], 'Partial');
    });

    test('outstanding excludes seized + rejected', () {
      // A: 7000 (#2) + B: 8000 + C: 3000 = 18000; D/E dropped.
      expect(r.outstandingTotal, 18000);
    });

    test('new customers counted in range', () {
      expect(r.newCustomerCount, 1); // only 2026-09-02
    });
  });

  group('LoanReport.emisDueOn (daily)', () {
    test('EMI due on 5 Sep → Loan A only (D seized is excluded)', () {
      final rows = LoanReport.emisDueOn(loans, DateTime(2026, 9, 5));
      expect(rows.length, 1);
      expect(rows.single.$1.id, 'A');
      expect(rows.single.$2.isPaid, true);
    });

    test('EMI due on 15 Sep → Loan C (partial)', () {
      final rows = LoanReport.emisDueOn(loans, DateTime(2026, 9, 15));
      expect(rows.length, 1);
      expect(rows.single.$1.id, 'C');
      expect(rows.single.$2.isPartial, true);
    });

    test('no EMI due on 1 Sep (only seized D was due then)', () {
      expect(LoanReport.emisDueOn(loans, DateTime(2026, 9, 1)), isEmpty);
    });
  });

  test('renders the monthly-report PDF to disk', () async {
    await initializeDateFormatting(); // intl locale data (app does this at startup)
    final bytes = await RealPdfService().loanBusinessReportBytes(buildSept());
    expect(bytes.lengthInBytes, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-'); // valid PDF header
    final out = File('${Directory.systemTemp.path}/loan_report_test.pdf');
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote ${bytes.lengthInBytes} bytes → ${out.path}');
  });
}
