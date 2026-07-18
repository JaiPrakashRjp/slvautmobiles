import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/customer.dart';
import '../models/installment.dart';
import '../models/monthly_report.dart';
import '../models/loan.dart';
import '../models/sale.dart';
import '../models/vehicle.dart';
import '../utils/formatters.dart';

abstract class PdfService {
  Future<void> previewInvoice({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  });

  /// Build the invoice PDF and hand it straight to the OS share sheet
  /// (WhatsApp / email / Drive …).
  Future<void> shareInvoice({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  });

  Future<void> installmentReceipt({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
    required Installment installment,
  });

  Future<void> payoffReceipt({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  });

  Future<void> previewNoc({
    required Loan loan,
    required Customer customer,
  });

  /// Business report over a period (month or custom range): sold/unsold,
  /// customers, dues. [previewMonthlyReport] opens the print preview;
  /// [shareMonthlyReport] hands the PDF to the OS share sheet.
  Future<void> previewMonthlyReport(MonthlyReport report);
  Future<void> shareMonthlyReport(MonthlyReport report);
}

class RealPdfService implements PdfService {
  const RealPdfService();

  // ── Brand palette (mirrors the app design system) ─────────────────────────
  static const PdfColor _navy    = PdfColor.fromInt(0xFF1B2A4E);
  static const PdfColor _gold    = PdfColor.fromInt(0xFFC8A951);
  static const PdfColor _bgWarm  = PdfColor.fromInt(0xFFE8E5DC); // page bg
  static const PdfColor _cream   = PdfColor.fromInt(0xFFF5F3EE); // card bg
  static const PdfColor _textMain= PdfColor.fromInt(0xFF0F1A33);
  static const PdfColor _divLine = PdfColor.fromInt(0xFFDDDAD3); // card divider

  // ── Business details (printed on the sale invoice) ───────────────────────────
  static const String _bizPhone = '8494992727';
  static const String _bizGstin = '29ETVPM6588PIZZ';
  static const String _bizState = 'Karnataka';
  static const String _branch1 =
      'No 84, 5th Cross, near Om Shakthi Temple, Hanumagiri Nagar, Bangalore 560061';
  static const String _branch2 =
      '30, 18th Main Rd, Munireddy Layout, Padmanabhanagar, Bengaluru, Karnataka 560061';

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// PDF-safe currency — built-in fonts lack the ₹ glyph.
  static String _curr(num amount) =>
      'Rs. ${NumberFormat('#,##,###', 'en_IN').format(amount.round())}';

  static const _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty',
    'Ninety'
  ];

  static String _twoDigit(int n) => n < 20
      ? _ones[n]
      : '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_ones[n % 10]}' : ''}';

  /// Indian-system rupees in words, e.g. 291500 → "Two Lakh Ninety One Thousand
  /// Five Hundred Rupees only".
  static String _amountInWords(int amount) {
    if (amount <= 0) return 'Zero Rupees only';
    var n = amount;
    final parts = <String>[];
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final hundred = n ~/ 100;
    n %= 100;
    if (crore > 0) parts.add('${_twoDigit(crore)} Crore');
    if (lakh > 0) parts.add('${_twoDigit(lakh)} Lakh');
    if (thousand > 0) parts.add('${_twoDigit(thousand)} Thousand');
    if (hundred > 0) parts.add('${_ones[hundred]} Hundred');
    if (n > 0) parts.add(_twoDigit(n));
    return '${parts.join(' ')} Rupees only';
  }

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/SLV logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ── Layout widgets ─────────────────────────────────────────────────────────

  /// Full-bleed navy app-bar header matching the mockup style.
  pw.Widget _header(
    String docTitle,
    pw.ImageProvider? logo, {
    String? ref,
  }) {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SLV Auto Consultant',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 3),
              pw.Text(docTitle.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: _gold,
                      letterSpacing: 1.4,
                      fontWeight: pw.FontWeight.bold)),
              if (ref != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(ref,
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white.shade(0.75))),
              ],
            ],
          ),
          logo != null
              ? pw.Image(logo, width: 56, height: 56, fit: pw.BoxFit.contain)
              : pw.Text('SLV',
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _gold)),
        ],
      ),
    );
  }

  /// Small grey section label above a card — mirrors "Assign Vehicle" etc.
  pw.Widget _label(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 5, left: 2),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1.0)),
    );
  }

  /// Rounded cream card wrapping a list of rows with dividers between them.
  pw.Widget _card(List<pw.Widget> rows) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _cream,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              pw.Divider(color: _divLine, thickness: 0.5, height: 0),
          ],
        ],
      ),
    );
  }

  /// Row inside a card — grey label on left, navy bold value on right.
  pw.Widget _row(String label, String value, {bool accent = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: accent ? _gold : _textMain)),
        ],
      ),
    );
  }

  /// Navy total bar — mirrors the "Confirm" button from the mockup.
  pw.Widget _totalBar(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _gold)),
        ],
      ),
    );
  }

  pw.Widget _footer() {
    final today = Formatters.date(DateTime.now());
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Generated on $today via SLV Auto Consultant',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 130,
                child: pw.Divider(color: _gold, thickness: 1),
              ),
              pw.SizedBox(height: 2),
              pw.Text('Authorised Signature',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sale invoice ───────────────────────────────────────────────────────────

  @override
  Future<void> previewInvoice({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  }) async {
    final doc =
        await _invoiceDoc(sale: sale, customer: customer, vehicle: vehicle);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Future<void> shareInvoice({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  }) async {
    final doc =
        await _invoiceDoc(sale: sale, customer: customer, vehicle: vehicle);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'invoice-${sale.invoiceNo ?? sale.id}.pdf',
    );
  }

  Future<pw.Document> _invoiceDoc({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  }) async {
    final logo = await _loadLogo();
    final branch = vehicle.branch?.label ?? customer.branch?.label;
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _invoiceHeader(logo),
          pw.Container(
            color: _gold,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text('SALE INVOICE',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 2)),
          ),
          pw.Expanded(
            child: pw.Container(
              color: _bgWarm,
              padding: const pw.EdgeInsets.fromLTRB(28, 14, 28, 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Bill To  |  Invoice details
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            _label('BILL TO'),
                            _card([
                              _row('Name', customer.fullName),
                              _row('Contact no.',
                                  Formatters.phone(customer.phone)),
                            ]),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            _label('INVOICE DETAILS'),
                            _card([
                              if (sale.invoiceNo != null)
                                _row('Invoice no.', sale.invoiceNo!),
                              if (sale.saleDate != null)
                                _row('Date', Formatters.date(sale.saleDate!)),
                              if (branch != null) _row('Branch', branch),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _label('PAYMENT'),
                  _card([
                    _row('Deposit type', sale.depositType.label),
                    if (sale.saleDate != null)
                      _row('Sale date', Formatters.date(sale.saleDate!)),
                    if (sale.salePrice != null)
                      _row('Total price', _curr(sale.salePrice!)),
                    _row('Advance received', _curr(sale.advance)),
                  ]),
                  // Balance drops as installments are paid.
                  _totalBar('BALANCE', _curr(sale.remainingAmount)),

                  _label('AMOUNT IN WORDS'),
                  _card([
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: pw.Text(_amountInWords(sale.collected),
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: _textMain)),
                    ),
                  ]),

                  _label('TERMS AND CONDITIONS'),
                  _card([
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: pw.Text('Thank you for doing business with us.',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ),
                  ]),

                  pw.Spacer(),
                  _branchFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
    return doc;
  }

  /// Invoice header: logo on the left, business details (name / phone / GSTIN /
  /// state) on the right.
  pw.Widget _invoiceHeader(pw.ImageProvider? logo) {
    return pw.Container(
      color: _navy,
      padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // White circular background so the logo stands out on the navy header.
          pw.Container(
            width: 74,
            height: 74,
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
              shape: pw.BoxShape.circle,
            ),
            padding: const pw.EdgeInsets.all(6),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.SizedBox(),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('SLV AUTO CONSULTANT',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('Phone no.: $_bizPhone',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.white.shade(0.85))),
              pw.Text('GSTIN: $_bizGstin',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.white.shade(0.85))),
              pw.Text('State: $_bizState',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.white.shade(0.85))),
            ],
          ),
        ],
      ),
    );
  }

  /// Both branch addresses, above a navy rule — no signature block.
  pw.Widget _branchFooter() {
    pw.Widget line(String tag, String addr) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 1),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: _cream,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: _gold, width: 0.5),
                ),
                child: pw.Text(tag,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(addr,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700, lineSpacing: 2)),
              ),
            ],
          ),
        );
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _navy, width: 1.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('BRANCH ADDRESSES',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                  letterSpacing: 1)),
          pw.SizedBox(height: 6),
          line('Branch 1', _branch1),
          line('Branch 2', _branch2),
        ],
      ),
    );
  }

  // ── Installment receipt ────────────────────────────────────────────────────

  @override
  Future<void> installmentReceipt({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
    required Installment installment,
  }) async {
    final logo = await _loadLogo();
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header('Instalment Receipt', logo, ref: sale.invoiceNo),
          pw.Expanded(
            child: pw.Container(
              color: _bgWarm,
              padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _label('CUSTOMER'),
                  _card([
                    _row('Name', customer.fullName),
                    _row('Mobile', Formatters.phone(customer.phone)),
                  ]),

                  _label('VEHICLE'),
                  _card([
                    _row('Reg. no.', vehicle.regNo),
                  ]),

                  _label('INSTALMENT'),
                  _card([
                    _row('Month', 'Month ${installment.monthNumber}'),
                    _row('Due date', Formatters.date(installment.dueDate)),
                    if (installment.paidDate != null)
                      _row('Paid on', Formatters.date(installment.paidDate!)),
                  ]),

                  _totalBar('AMOUNT PAID', _curr(installment.amount)),
                  pw.Spacer(),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // ── Payoff receipt ─────────────────────────────────────────────────────────

  @override
  Future<void> payoffReceipt({
    required Sale sale,
    required Customer customer,
    required Vehicle vehicle,
  }) async {
    final logo = await _loadLogo();
    final paidTotal = sale.salePrice ?? sale.advance;
    final closedOn = sale.closedAt != null
        ? Formatters.date(sale.closedAt!)
        : Formatters.date(DateTime.now());
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header('Early Payoff Receipt', logo, ref: sale.invoiceNo),
          pw.Expanded(
            child: pw.Container(
              color: _bgWarm,
              padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _label('CUSTOMER'),
                  _card([
                    _row('Name', customer.fullName),
                    _row('Mobile', Formatters.phone(customer.phone)),
                  ]),

                  _label('VEHICLE'),
                  _card([
                    _row('Reg. no.', vehicle.regNo),
                  ]),

                  _label('SETTLEMENT'),
                  _card([
                    if (sale.saleDate != null)
                      _row('Sale date', Formatters.date(sale.saleDate!)),
                    _row('Total price', _curr(paidTotal)),
                    _row('Instalments settled', '${sale.totalInstallments}'),
                    _row('Closed on', closedOn),
                  ]),

                  _totalBar('FULL AMOUNT RECEIVED', _curr(paidTotal)),

                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _cream,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'This confirms that ${customer.fullName} has fully settled '
                      'all outstanding instalments for vehicle ${vehicle.regNo}. '
                      'SLV Auto Consultant has no further financial claims on this sale.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700, lineSpacing: 4),
                    ),
                  ),

                  pw.Spacer(),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // ── Loan NOC ───────────────────────────────────────────────────────────────

  @override
  Future<void> previewNoc({
    required Loan loan,
    required Customer customer,
  }) async {
    final logo = await _loadLogo();
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header('No Objection Certificate', logo),
          pw.Expanded(
            child: pw.Container(
              color: _bgWarm,
              padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _label('CUSTOMER'),
                  _card([
                    _row('Name', customer.fullName),
                    _row('Mobile', Formatters.phone(customer.phone)),
                  ]),

                  _label('LOAN DETAILS'),
                  _card([
                    _row('Principal', _curr(loan.principal)),
                    _row('Interest rate', '${loan.rate}% p.a. (flat)'),
                    _row('Tenure', '${loan.tenureMonths} months'),
                    _row('Disbursed on', Formatters.date(loan.disbursementDate)),
                    _row('Total repaid', _curr(loan.totalPaid)),
                  ]),

                  _totalBar('STATUS', 'CLOSED  —  NOC ISSUED'),

                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _cream,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      'This is to certify that ${customer.fullName} '
                      '(${Formatters.phone(customer.phone)}) has fully repaid the '
                      'loan detailed above and that SLV Auto Consultant has no '
                      'further claim in respect of it.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700, lineSpacing: 4),
                    ),
                  ),

                  pw.Spacer(),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  // ── Monthly / period report ─────────────────────────────────────────────

  @override
  Future<void> previewMonthlyReport(MonthlyReport report) async {
    final doc = await _monthlyReportDoc(report);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Future<void> shareMonthlyReport(MonthlyReport report) async {
    final doc = await _monthlyReportDoc(report);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'report-${report.label.replaceAll(' ', '-')}.pdf',
    );
  }

  Future<pw.Document> _monthlyReportDoc(MonthlyReport r) async {
    final logo = await _loadLogo();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 28),
        header: (_) => _reportHeader(logo, r.label),
        build: (_) => [
          _label('OVERVIEW'),
          _statGrid([
            ('Vehicles sold', '${r.soldCount}', _curr(r.soldValue)),
            ('Sales value', _curr(r.soldValue), 'this period'),
            ('Unsold (in stock)', '${r.unsold.length}', 'current inventory'),
            ('New customers', '${r.newCustomerCount}', 'added this period'),
            ('Collected', _curr(r.collected), 'this period'),
            ('Outstanding', _curr(r.outstanding), 'from these sales'),
          ]),
          _label('SALES THIS PERIOD'),
          if (r.sales.isEmpty)
            _emptyLine('No sales in this period.')
          else
            _table(
              ['Date', 'Customer', 'Vehicle', 'Price', 'Received', 'Balance'],
              [
                for (final s in r.sales)
                  [
                    Formatters.date(s.date),
                    s.customerName,
                    s.vehicle,
                    _curr(s.price),
                    _curr(s.received),
                    _curr(s.balance),
                  ],
                [
                  'Total · ${r.soldCount}',
                  '',
                  '',
                  _curr(r.soldValue),
                  _curr(r.collected),
                  _curr(r.outstanding),
                ],
              ],
              rightAlign: const {3, 4, 5},
              totalLastRow: true,
            ),
          _label('OUTSTANDING DUES'),
          if (r.dues.isEmpty)
            _emptyLine('Nothing outstanding from this period.')
          else
            _table(
              ['Customer', 'Phone', 'Vehicle', 'Balance'],
              [
                for (final s in r.dues)
                  [s.customerName, s.phone, s.vehicle, _curr(s.balance)],
                ['Total outstanding', '', '', _curr(r.outstanding)],
              ],
              rightAlign: const {3},
              totalLastRow: true,
            ),
          _label('UNSOLD VEHICLES (IN STOCK)'),
          if (r.unsold.isEmpty)
            _emptyLine('No vehicles in stock.')
          else
            _table(
              ['Vehicle', 'Model', 'Type', 'Purchased'],
              [
                for (final v in r.unsold)
                  [
                    v.identifier,
                    v.model,
                    v.type,
                    v.purchaseDate == null
                        ? '—'
                        : Formatters.date(v.purchaseDate!),
                  ],
              ],
            ),
        ],
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SLV Auto Consultant · Report',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ),
      ),
    );
    return doc;
  }

  pw.Widget _reportHeader(pw.ImageProvider? logo, String label) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          logo != null
              ? pw.Image(logo, width: 44, height: 44, fit: pw.BoxFit.contain)
              : pw.SizedBox(width: 44, height: 44),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('SLV AUTO CONSULTANT',
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              pw.SizedBox(height: 2),
              pw.Text('Monthly report  ·  $label',
                  style: const pw.TextStyle(fontSize: 10, color: _gold)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _statGrid(List<(String, String, String)> stats) {
    pw.Widget box((String, String, String) s) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _cream,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.$2,
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              pw.SizedBox(height: 2),
              pw.Text(s.$1,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text(s.$3,
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        );
    final rows = <pw.Widget>[];
    for (var i = 0; i < stats.length; i += 3) {
      final chunk = stats.skip(i).take(3).toList();
      rows.add(pw.Row(
        children: [
          for (var j = 0; j < 3; j++) ...[
            pw.Expanded(child: j < chunk.length ? box(chunk[j]) : pw.SizedBox()),
            if (j < 2) pw.SizedBox(width: 8),
          ],
        ],
      ));
      rows.add(pw.SizedBox(height: 8));
    }
    return pw.Column(children: rows);
  }

  pw.Widget _table(List<String> headers, List<List<String>> rows,
      {Set<int> rightAlign = const {}, bool totalLastRow = false}) {
    final aligns = <int, pw.Alignment>{
      for (var i = 0; i < headers.length; i++)
        i: rightAlign.contains(i)
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    };
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: null,
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _textMain),
      cellAlignments: aligns,
      cellHeight: 20,
      oddRowDecoration: const pw.BoxDecoration(color: _cream),
      rowDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFBFAF6)),
    );
  }

  pw.Widget _emptyLine(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      );
}
