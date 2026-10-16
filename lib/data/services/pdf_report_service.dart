import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone.dart';
import '../../core/utils/quantity.dart';
import '../models/models.dart';
import 'report_builder.dart';

/// Builds the period report as a PDF, entirely on the device.
///
/// Uses the built-in PDF fonts, which only cover Latin characters. Text in
/// other scripts (e.g. Urdu) is replaced until a Unicode font is bundled.
class PdfReportService {
  const PdfReportService();

  static final PdfColor _ink = PdfColor.fromInt(0xFF101828);
  static final PdfColor _muted = PdfColor.fromInt(0xFF667085);
  static final PdfColor _brand = PdfColor.fromInt(0xFF0F766E);
  static final PdfColor _line = PdfColor.fromInt(0xFFE4E7EC);
  static final PdfColor _fill = PdfColor.fromInt(0xFFF2F4F7);

  String fileName(ReportData data) {
    final slug = data.group.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'roomeez-$slug-${AppDates.iso(data.range.start)}-to-${AppDates.iso(data.range.end)}.pdf';
  }

  Future<Uint8List> build(ReportData data) async {
    final doc = pw.Document(title: 'Expense report - ${_t(data.group.name)}', author: 'Roomeez');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Roomeez  |  Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (context) => [
          _header(data),
          pw.SizedBox(height: 18),
          _sectionTitle('Summary'),
          _keyValueTable([
            ('Total expenses', Money.format(data.summary.totalExpensesPaisa)),
            ('Number of expenses', '${data.summary.expenseCount}'),
            ('Paid from personal money', Money.format(data.summary.paidPersonallyPaisa)),
            ('Paid from group fund', Money.format(data.summary.paidFromFundPaisa)),
            if (data.summary.voidedCount > 0) ('Voided entries (excluded)', '${data.summary.voidedCount}'),
          ]),
          pw.SizedBox(height: 16),
          ..._fundSection(data),
          _sectionTitle('Members in this period'),
          _membersTable(data),
          pw.SizedBox(height: 16),
          _sectionTitle('Daily expenses'),
          if (data.days.isEmpty) pw.Text('No expenses recorded in this period.', style: pw.TextStyle(color: _muted)),
          for (final day in data.days) ..._day(data, day),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(ReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EXPENSE REPORT',
          style: pw.TextStyle(fontSize: 9, color: _brand, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _t(data.group.name),
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Group code ${data.group.code}   |   ${_t(AppDates.range(data.range))} (${data.range.dayCount} days)',
          style: pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.Text(
          'Generated ${_t(AppDates.dateTime(data.generatedAt))}',
          style: pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _line),
      ],
    );
  }

  List<pw.Widget> _fundSection(ReportData data) {
    final fund = data.fundAsOfEnd;
    if (!fund.hasFund && data.contributions.isEmpty) return const [];
    return [
      _sectionTitle('Group fund (as of ${AppDates.day(data.range.end)})'),
      pw.Text(
        'Contributions go into the group fund. They are not expenses.',
        style: pw.TextStyle(fontSize: 9, color: _muted),
      ),
      pw.SizedBox(height: 6),
      _keyValueTable([
        ('Total contributions to date', Money.format(fund.contributedPaisa)),
        ('Spent from group fund to date', Money.format(fund.spentPaisa)),
        ('Remaining in group fund', Money.format(fund.remainingPaisa)),
      ]),
      if (data.contributions.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Contributions in this period',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink),
        ),
        pw.SizedBox(height: 4),
        _table(
          headers: const ['Date', 'Member', 'Type', 'Amount'],
          rows: [
            for (final c in data.contributions)
              [AppDates.day(c.date), data.nameOf(c.memberUserId), c.type.label, Money.format(c.amountPaisa)],
          ],
          numericColumns: const {3},
        ),
      ],
      pw.SizedBox(height: 16),
    ];
  }

  pw.Widget _membersTable(ReportData data) {
    final rows = <List<String>>[];
    for (final m in data.members) {
      final balance = data.summary.balanceOf(m.userId);
      final until = m.endDate == null ? 'Present' : '${AppDates.day(m.endDate!)} (${m.status.label.toLowerCase()})';
      rows.add([
        m.displayName,
        m.phone != null ? PhoneNumber.format(m.phone!) : (m.email ?? '-'),
        AppDates.day(m.startDate),
        until,
        Money.format(balance?.paidInPaisa ?? 0, withCurrency: false),
        Money.format(balance?.sharePaisa ?? 0, withCurrency: false),
        Money.format(balance?.netPaisa ?? 0, withCurrency: false, signed: true),
      ]);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _table(
          headers: const ['Member', 'Contact', 'Member since', 'Until', 'Paid in', 'Share', 'Net'],
          rows: rows,
          numericColumns: const {4, 5, 6},
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Amounts in PKR for this period. Paid in = contributions + expenses paid personally. '
          'Share = equal split among the members each expense was shared with.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }

  List<pw.Widget> _day(ReportData data, ReportDay day) {
    return [
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: _fill,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${AppDates.weekday(day.date)} ${day.date.year}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _ink),
            ),
            pw.Text(
              Money.format(day.totalPaisa),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _ink),
            ),
          ],
        ),
      ),
      for (final e in day.expenses) _expense(data, e),
    ];
  }

  pw.Widget _expense(ReportData data, Expense e) {
    final paidBy = e.paymentSource == PaymentSource.groupFund
        ? 'Group fund'
        : '${data.nameOf(e.paidByUserId ?? e.createdByUserId)} (personal)';
    return pw.Container(
      margin: const pw.EdgeInsets.only(left: 8, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${_t(e.title)}  [${e.category.label}]',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _ink),
                ),
              ),
              pw.Text(Money.format(e.totalPaisa), style: pw.TextStyle(color: _ink)),
            ],
          ),
          pw.Text(
            'Added by ${_t(data.nameOf(e.createdByUserId))}  |  Paid by ${_t(paidBy)}'
            '${e.isEdited ? '  |  Edited ${_t(AppDates.dateTime(e.editedAt!))}' : ''}',
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
          if (e.isItemized) ...[
            pw.SizedBox(height: 3),
            _table(
              headers: const ['Item', 'Qty', 'Price', 'Total'],
              rows: [
                for (final item in e.items)
                  [
                    item.name,
                    Quantity.format(item.quantityMilli),
                    Money.format(item.unitPricePaisa, withCurrency: false),
                    Money.format(item.lineTotalPaisa, withCurrency: false),
                  ],
              ],
              numericColumns: const {1, 2, 3},
              compact: true,
            ),
          ],
          if (e.notes != null && e.notes!.trim().isNotEmpty)
            pw.Text('Note: ${_t(e.notes!)}', style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      _t(text),
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink),
    ),
  );

  pw.Widget _keyValueTable(List<(String, String)> rows) {
    return pw.Table(
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      children: [
        for (final (label, value) in rows)
          pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(_t(label))),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  _t(value),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Set<int> numericColumns = const {},
    bool compact = false,
  }) {
    final fontSize = compact ? 8.5 : 9.0;
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: [
        for (final row in rows) [for (final cell in row) _t(cell)],
      ],
      headerStyle: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: _ink),
      headerDecoration: pw.BoxDecoration(color: _fill),
      cellStyle: pw.TextStyle(fontSize: fontSize, color: _ink),
      cellPadding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: compact ? 2 : 3),
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: _line, width: 0.5),
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: numericColumns.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
      headerAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: numericColumns.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      },
    );
  }

  /// Keeps text within Latin-1, which the built-in PDF fonts support.
  static String _t(String input) {
    const replacements = {'–': '-', '—': '-', '‘': "'", '’': "'", '“': '"', '”': '"', '…': '...', '•': '-'};
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (replacements.containsKey(char)) {
        buffer.write(replacements[char]);
      } else if (rune < 0x20 && rune != 0x0A) {
        buffer.write(' ');
      } else if (rune <= 0xFF) {
        buffer.write(char);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }
}
