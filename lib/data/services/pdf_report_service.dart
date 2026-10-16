import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/theme/app_theme.dart' show AppColors;
import '../../core/neu/neu.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/category_icon.dart';
import '../../core/widgets/common.dart' show MemberAvatar;
import '../models/models.dart';
import 'balance_calculator.dart';
import 'report_builder.dart';

/// Builds the period report as a one-page PDF, entirely on the device.
///
/// The page uses the app's neumorphic look: one soft base color with raised
/// cards. Everything fits on a single A4 page, so the expense list adapts to
/// the space that is left: one line per expense, then two columns, then daily
/// totals for long periods. Item details stay in the app.
///
/// Poppins only covers Latin text. Other scripts (e.g. Urdu) are replaced
/// until a Unicode font is bundled.
class PdfReportService {
  const PdfReportService();

  static Future<_Fonts>? _fonts;

  String fileName(ReportData data) {
    final slug = data.group.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'roomeez-$slug-${AppDates.iso(data.range.start)}-to-${AppDates.iso(data.range.end)}.pdf';
  }

  Future<Uint8List> build(ReportData data) async {
    final fonts = await _loadFonts();
    final doc = pw.Document(title: 'Expense report - ${_t(data.group.name)}', author: 'Roomeez');
    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 26),
          theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.semiBold),
          buildBackground: (context) => pw.FullPage(ignoreMargins: true, child: pw.Container(color: _base)),
        ),
        build: (context) => _ReportPage(data, fonts).build(),
      ),
    );
    return doc.save();
  }

  static Future<_Fonts> _loadFonts() async {
    try {
      return await (_fonts ??= _Fonts.load());
    } catch (_) {
      _fonts = null;
      rethrow;
    }
  }
}

class _Fonts {
  const _Fonts({required this.light, required this.regular, required this.medium, required this.semiBold});

  final pw.Font light;
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;

  static Future<_Fonts> load() async {
    Future<pw.Font> poppins(String weight) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    return _Fonts(
      light: await poppins('Light'),
      regular: await poppins('Regular'),
      medium: await poppins('Medium'),
      semiBold: await poppins('SemiBold'),
    );
  }
}

const NeuPalette _neu = NeuPalette.light;
final PdfColor _base = _pdf(_neu.base);
final PdfColor _ink = _pdf(_neu.text);
final PdfColor _muted = _pdf(_neu.muted);
final PdfColor _accent = _pdf(_neu.accent);
final PdfColor _positive = _pdf(AppColors.light.positive);
final PdfColor _negative = _pdf(AppColors.light.negative);
final PdfColor _line = _pdf(Color.lerp(_neu.base, _neu.shade, 0.4)!);

// Pressed-in tracks: a touch darker at the top, lighter at the bottom.
final PdfColor _insetTop = _pdf(Color.lerp(_neu.base, _neu.shade, 0.45)!);
final PdfColor _insetBottom = _pdf(Color.lerp(_neu.base, _neu.highlight, 0.6)!);

PdfColor _pdf(Color color) => PdfColor.fromInt(color.toARGB32());

String get _houseSvg {
  final hex = _neu.accent.toARGB32().toRadixString(16).substring(2);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="#$hex" d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>';
}

/// Height of one line in the expense list; long lists use tighter lines.
const double _rowHeight = 18;
const double _tightRowHeight = 16;

class _ReportPage {
  _ReportPage(this.data, this.fonts);

  final ReportData data;
  final _Fonts fonts;

  pw.Widget build() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(),
        pw.SizedBox(height: 24),
        _stats(),
        pw.SizedBox(height: 22),
        _balancesAndCategories(),
        pw.SizedBox(height: 22),
        pw.Expanded(
          child: pw.Align(alignment: pw.Alignment.topCenter, child: _expenses()),
        ),
        pw.SizedBox(height: 14),
        _footer(),
      ],
    );
  }

  // ---------------------------------------------------------------- sections

  pw.Widget _header() {
    final days = data.range.dayCount;
    return pw.Row(
      children: [
        _raisedBox(
          width: 46,
          height: 46,
          alignment: pw.Alignment.center,
          circle: true,
          depth: 3.5,
          child: pw.SvgImage(svg: _houseSvg, width: 22, height: 22),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label('Expense report'),
              pw.Text(_t(data.group.name), maxLines: 1, style: _style(size: 22, font: fonts.light)),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(_t(AppDates.range(data.range)), style: _style(size: 10.5, font: fonts.medium)),
            pw.Text('$days ${days == 1 ? 'day' : 'days'}', style: _style(size: 8, color: _muted)),
          ],
        ),
      ],
    );
  }

  pw.Widget _stats() {
    final summary = data.summary;
    final fund = data.fundAsOfEnd;
    final days = data.range.dayCount;
    final count = summary.expenseCount;
    final cards = [
      _stat(
        'Total spent',
        _money(summary.totalExpensesPaisa),
        '$count ${count == 1 ? 'expense' : 'expenses'}',
        color: _accent,
      ),
      _stat(
        'Daily average',
        _money((summary.totalExpensesPaisa + days ~/ 2) ~/ days),
        'over $days ${days == 1 ? 'day' : 'days'}',
      ),
      if (fund.hasFund)
        _stat('Group fund left', _money(fund.remainingPaisa), 'of ${_money(fund.contributedPaisa)} added')
      else
        _stat('Members', '${data.members.length}', 'in this period'),
    ];
    return pw.Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[if (i > 0) pw.SizedBox(width: 16), pw.Expanded(child: cards[i])],
      ],
    );
  }

  pw.Widget _stat(String label, String value, String caption, {PdfColor? color}) {
    return _raisedBox(
      padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _label(label),
          pw.SizedBox(height: 3),
          pw.Text(
            _t(value),
            maxLines: 1,
            style: _style(size: 16, font: fonts.light, color: color),
          ),
          pw.Text(_t(caption), maxLines: 1, style: _style(size: 7.5, color: _muted)),
        ],
      ),
    );
  }

  /// Balances and spending by category, side by side at the same height.
  pw.Widget _balancesAndCategories() {
    const maxMembers = 10;
    const maxCategories = 5;
    final balances = data.memberBalances;
    final memberRows = math.min(balances.length, maxMembers);
    final categoryRows = math.max(1, math.min(data.summary.byCategory.length, maxCategories));
    final height = math.max(
      _cardChrome + 16 + memberRows * _balanceRowHeight + 18,
      _cardChrome + categoryRows * _categoryRowHeight,
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 11,
          child: _card('Balances', height: height, child: _balances(maxMembers)),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          flex: 8,
          child: _card(
            'By category',
            height: height,
            child: _categories(math.max(maxCategories, (height - _cardChrome) ~/ _categoryRowHeight)),
          ),
        ),
      ],
    );
  }

  static const double _cardChrome = 28 + 16 + 8; // padding + title + gap
  static const double _balanceRowHeight = 24;
  static const double _categoryRowHeight = 28;

  pw.Widget _balances(int maxRows) {
    final balances = data.memberBalances;
    final shown = balances.length > maxRows ? balances.take(maxRows - 1).toList() : balances;
    final hidden = balances.length - shown.length;
    pw.Widget heading(String text, double width) => pw.SizedBox(
      width: width,
      child: pw.Text(text.toUpperCase(), textAlign: pw.TextAlign.right, style: _tiny),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 16,
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text('MEMBER', style: _tiny)),
              heading('Paid', 48),
              heading('Share', 48),
              heading('Balance', 56),
            ],
          ),
        ),
        for (final (i, b) in shown.indexed) _balanceRow(b, last: i == shown.length - 1 && hidden == 0),
        if (hidden > 0)
          pw.SizedBox(
            height: _balanceRowHeight,
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('+ $hidden more members', style: _style(size: 8, color: _muted)),
            ),
          ),
        pw.Spacer(),
        pw.Text('+ gets money back     - owes money', style: _style(size: 6.8, color: _muted)),
      ],
    );
  }

  pw.Widget _balanceRow(MemberBalance b, {required bool last}) {
    final net = _rupees(b.netPaisa);
    final color = net > 0 ? _positive : (net < 0 ? _negative : _muted);
    pw.Widget amount(String text, double width, {PdfColor? color, pw.Font? font}) => pw.SizedBox(
      width: width,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: _style(size: 8.5, color: color, font: font),
      ),
    );
    return _lined(
      last: last,
      height: _balanceRowHeight,
      child: pw.Row(
        children: [
          _avatar(b.name, 17),
          pw.SizedBox(width: 7),
          pw.Expanded(
            child: pw.Text(_t(b.name), maxLines: 1, style: _style(size: 8.5, font: fonts.medium)),
          ),
          amount(_amount(b.paidInPaisa), 48, color: _muted),
          amount(_amount(b.sharePaisa), 48, color: _muted),
          amount(_amount(b.netPaisa, signed: true), 56, color: color, font: fonts.semiBold),
        ],
      ),
    );
  }

  pw.Widget _categories(int maxRows) {
    final entries = data.summary.byCategory;
    if (entries.isEmpty) {
      return pw.Text('No spending in this period', style: _style(size: 8, color: _muted));
    }
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final rows = <(ExpenseCategory?, String, int)>[
      for (final e in entries.length > maxRows ? entries.take(maxRows - 1) : entries) (e.key, e.key.label, e.value),
      if (entries.length > maxRows)
        (null, '${entries.length - maxRows + 1} more', entries.skip(maxRows - 1).fold(0, (sum, e) => sum + e.value)),
    ];
    return pw.Column(
      children: [
        for (final (category, label, paisa) in rows)
          pw.SizedBox(
            height: _categoryRowHeight,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    if (category != null) ...[_dot(_pdf(category.color)), pw.SizedBox(width: 5)],
                    pw.Expanded(
                      child: pw.Text(label, style: _style(size: 8.5, font: fonts.medium)),
                    ),
                    pw.Text(_amount(paisa), style: _style(size: 8.5, color: _muted)),
                  ],
                ),
                pw.SizedBox(height: 4),
                _bar(paisa / total, category == null ? _muted : _pdf(category.color)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _expenses() {
    return _raisedBox(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: pw.LayoutBuilder(
        builder: (context, constraints) {
          final list = _ExpenseList.fit(data, height: constraints!.maxHeight - 16 - 6);
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(
                height: 16,
                child: pw.Row(
                  children: [
                    pw.Expanded(child: _label(list.title)),
                    pw.Text(_t(list.caption), style: _style(size: 7.5, color: _muted)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              if (list.isEmpty)
                pw.SizedBox(
                  height: 48,
                  child: pw.Center(
                    child: pw.Text('No expenses in this period', style: _style(size: 9, color: _muted)),
                  ),
                )
              else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final (i, column) in list.columns.indexed) ...[
                      if (i > 0) pw.SizedBox(width: 24),
                      pw.Expanded(
                        child: _column(column, detailed: list.columns.length == 1, rowHeight: list.rowHeight),
                      ),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  pw.Widget _column(List<_Line> lines, {required bool detailed, required double rowHeight}) {
    return pw.Column(
      children: [
        for (final (i, line) in lines.indexed)
          _lined(
            last: i == lines.length - 1,
            height: rowHeight,
            child: switch (line) {
              _ExpenseLine(:final expense) => _expenseRow(expense, detailed: detailed),
              _TotalLine(:final label, :final detail, :final paisa) => _totalRow(label, detail, paisa),
            },
          ),
      ],
    );
  }

  pw.Widget _expenseRow(Expense e, {required bool detailed}) {
    final paidBy = e.paymentSource == PaymentSource.groupFund
        ? 'Group fund'
        : data.nameOf(e.paidByUserId ?? e.createdByUserId);
    return pw.Row(
      children: [
        pw.SizedBox(
          width: detailed ? 62 : 38,
          child: pw.Text(
            detailed ? AppDates.weekday(e.date) : AppDates.short(e.date),
            style: _style(size: 7.8, color: _muted),
          ),
        ),
        _dot(_pdf(e.category.color)),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(_t(e.title), maxLines: 1, style: _style(size: 8.5, font: fonts.medium)),
        ),
        if (detailed)
          pw.SizedBox(
            width: 120,
            child: pw.Text(_t(paidBy), maxLines: 1, style: _style(size: 7.8, color: _muted)),
          ),
        pw.SizedBox(
          width: 52,
          child: pw.Text(_amount(e.totalPaisa), textAlign: pw.TextAlign.right, style: _style(size: 8.5)),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, String detail, int paisa) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 76,
          child: pw.Text(_t(label), maxLines: 1, style: _style(size: 8.5, font: fonts.medium)),
        ),
        pw.Expanded(
          child: pw.Text(_t(detail), maxLines: 1, style: _style(size: 7.8, color: _muted)),
        ),
        pw.Text(_amount(paisa), style: _style(size: 8.5)),
      ],
    );
  }

  pw.Widget _footer() {
    final voided = data.summary.voidedCount;
    final notes = [
      'Generated ${AppDates.dateTime(data.generatedAt)}',
      'Amounts in PKR',
      if (voided > 0) '$voided voided ${voided == 1 ? 'entry' : 'entries'} not included',
    ];
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(_t(notes.join('  ·  ')), style: _style(size: 6.8, color: _muted)),
        ),
        pw.Text(
          'ROOMEEZ',
          style: _style(size: 7, font: fonts.semiBold, color: _accent, spacing: 2),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- pieces

  pw.Widget _card(String title, {required double height, required pw.Widget child}) {
    return _raisedBox(
      height: height,
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(height: 16, child: _label(title)),
          pw.SizedBox(height: 8),
          pw.Expanded(child: child),
        ],
      ),
    );
  }

  /// A row with a soft engraved line under it.
  pw.Widget _lined({required pw.Widget child, required double height, required bool last}) {
    return pw.Container(
      height: height,
      decoration: last
          ? null
          : pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
            ),
      alignment: pw.Alignment.centerLeft,
      child: child,
    );
  }

  /// A pressed-in track filled up to [fraction], like the app's fund bar.
  pw.Widget _bar(double fraction, PdfColor color) {
    final filled = (fraction.clamp(0, 1) * 1000).round().clamp(12, 1000);
    return pw.Container(
      height: 5,
      decoration: _inset(radius: 2.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: filled,
            child: pw.Container(
              decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.all(pw.Radius.circular(2.5))),
            ),
          ),
          if (filled < 1000) pw.Expanded(flex: 1000 - filled, child: pw.SizedBox()),
        ],
      ),
    );
  }

  pw.Widget _avatar(String name, double size) {
    final color = MemberAvatar.colorFor(name);
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: _pdf(Color.lerp(_neu.base, color, 0.2)!)),
      child: pw.Text(
        _t(MemberAvatar.initials(name)),
        style: _style(size: size * 0.38, font: fonts.semiBold, color: _pdf(color)),
      ),
    );
  }

  pw.Widget _dot(PdfColor color) => pw.Container(
    width: 6,
    height: 6,
    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color),
  );

  pw.Widget _label(String text) => pw.Text(
    text.toUpperCase(),
    style: _style(size: 7, font: fonts.semiBold, color: _muted, spacing: 1.8),
  );

  pw.TextStyle get _tiny => _style(size: 6.2, font: fonts.medium, color: _muted, spacing: 1.2);

  pw.TextStyle _style({double size = 9, pw.Font? font, PdfColor? color, double? spacing}) =>
      pw.TextStyle(font: font ?? fonts.regular, fontSize: size, color: color ?? _ink, letterSpacing: spacing);

  /// A soft raised surface, like `NeuBox` in the app.
  pw.Widget _raisedBox({
    required pw.Widget child,
    double? width,
    double? height,
    pw.EdgeInsets? padding,
    pw.Alignment? alignment,
    double radius = 18,
    double depth = 4,
    bool circle = false,
  }) {
    return _Raised(
      radius: circle ? (width ?? 0) / 2 : radius,
      depth: depth,
      child: pw.Container(
        width: width,
        height: height,
        padding: padding,
        alignment: alignment,
        decoration: pw.BoxDecoration(
          color: _base,
          shape: circle ? pw.BoxShape.circle : pw.BoxShape.rectangle,
          borderRadius: circle ? null : pw.BorderRadius.all(pw.Radius.circular(radius)),
        ),
        child: child,
      ),
    );
  }

  static pw.BoxDecoration _inset({double radius = 12}) => pw.BoxDecoration(
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(radius)),
    gradient: pw.LinearGradient(
      begin: pw.Alignment.topCenter,
      end: pw.Alignment.bottomCenter,
      colors: [_insetTop, _insetBottom],
    ),
  );

  static String _money(int paisa) => Money.format(paisa, roundToRupee: true);

  static String _amount(int paisa, {bool signed = false}) =>
      Money.format(paisa, withCurrency: false, signed: signed, roundToRupee: true);

  static int _rupees(int paisa) => paisa.sign * ((paisa.abs() + 50) ~/ 100);

  static String _count(int n) => '$n ${n == 1 ? 'expense' : 'expenses'}';
}

/// What the expense list shows, chosen to fit the space on the page.
class _ExpenseList {
  const _ExpenseList({
    required this.title,
    required this.columns,
    required this.caption,
    this.rowHeight = _tightRowHeight,
  });

  /// Picks the most detailed layout that fits in [height]: every expense,
  /// then daily totals, then monthly totals.
  factory _ExpenseList.fit(ReportData data, {required double height}) {
    final expenses = [for (final day in data.days) ...day.expenses];
    if (expenses.isEmpty) return const _ExpenseList(title: 'Expenses', columns: [], caption: '');
    final roomy = math.max(1, height ~/ _rowHeight);
    final perColumn = math.max(1, height ~/ _tightRowHeight);
    final caption = '${_ReportPage._count(expenses.length)} · ${_ReportPage._money(data.summary.totalExpensesPaisa)}';
    final capacity = perColumn * 2;
    if (expenses.length <= roomy) {
      return _ExpenseList(
        title: 'Expenses',
        columns: [
          [for (final e in expenses) _ExpenseLine(e)],
        ],
        caption: caption,
        rowHeight: _rowHeight,
      );
    }
    if (expenses.length <= capacity) {
      return _ExpenseList(
        title: 'Expenses',
        columns: _split([for (final e in expenses) _ExpenseLine(e)], 2),
        caption: caption,
      );
    }
    if (data.days.length <= capacity) {
      return _ExpenseList(
        title: 'Daily totals',
        columns: _split([for (final d in data.days) _TotalLine.day(d)], 2),
        caption: caption,
      );
    }
    // A full month always fits in three columns of dates and totals.
    if (data.days.length <= perColumn * 3) {
      return _ExpenseList(
        title: 'Daily totals',
        columns: _split([for (final d in data.days) _TotalLine(AppDates.weekday(d.date), '', d.totalPaisa)], 3),
        caption: caption,
      );
    }
    final months = <List<ReportDay>>[];
    for (final d in data.days) {
      final previous = months.isEmpty ? null : months.last.first.date;
      if (previous != null && previous.year == d.date.year && previous.month == d.date.month) {
        months.last.add(d);
      } else {
        months.add([d]);
      }
    }
    // Months that still don't fit are folded into the first line.
    final shown = months.length <= capacity ? months : months.sublist(months.length - (capacity - 1));
    final folded = months.sublist(0, months.length - shown.length);
    return _ExpenseList(
      title: 'Monthly totals',
      columns: _split([
        if (folded.isNotEmpty)
          _TotalLine.days('Before ${AppDates.month(shown.first.first.date)}', [for (final m in folded) ...m]),
        for (final m in shown) _TotalLine.days(AppDates.month(m.first.date), m),
      ], 2),
      caption: caption,
    );
  }

  final String title;
  final List<List<_Line>> columns;
  final String caption;
  final double rowHeight;

  bool get isEmpty => columns.isEmpty;

  /// Splits [lines] into [count] columns, filled top to bottom.
  static List<List<_Line>> _split(List<_Line> lines, int count) {
    final perColumn = (lines.length + count - 1) ~/ count;
    return [
      for (var start = 0; start < lines.length; start += perColumn)
        lines.sublist(start, math.min(start + perColumn, lines.length)),
    ];
  }
}

sealed class _Line {
  const _Line();
}

class _ExpenseLine extends _Line {
  const _ExpenseLine(this.expense);
  final Expense expense;
}

/// A day, a month or an older stretch, shown as one total.
class _TotalLine extends _Line {
  const _TotalLine(this.label, this.detail, this.paisa);

  factory _TotalLine.day(ReportDay day) => _TotalLine(
    AppDates.weekday(day.date),
    // A day with a single expense is more useful by name.
    day.expenses.length == 1 ? day.expenses.single.title : _ReportPage._count(day.expenses.length),
    day.totalPaisa,
  );

  factory _TotalLine.days(String label, List<ReportDay> days) => _TotalLine(
    label,
    _ReportPage._count(days.fold(0, (sum, d) => sum + d.expenses.length)),
    days.fold(0, (sum, d) => sum + d.totalPaisa),
  );

  final String label;
  final String detail;
  final int paisa;
}

/// Keeps text to characters Poppins can draw.
String _t(String input) {
  const allowed = {'–', '—', '‘', '’', '“', '”', '…', '•'};
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    if (rune < 0x20 && rune != 0x0A) {
      buffer.write(' ');
    } else if (rune <= 0x17F || allowed.contains(char)) {
      buffer.write(char);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

/// Paints the two neumorphic shadows behind [child]: light to the top left,
/// dark to the bottom right. The pdf package's own box shadow is a blurred
/// square, which shows hard corners on rounded cards.
class _Raised extends pw.SingleChildWidget {
  _Raised({required pw.Widget child, required this.radius, required this.depth}) : super(child: child);

  final double radius;
  final double depth;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final box = this.box!;
    final blur = (depth * 2).round();
    final pad = blur * 2;
    for (final (color, offset) in [(_neu.highlight, -depth), (_neu.shade.withValues(alpha: 0.6), depth)]) {
      final image = im.Image(width: box.width.round() + pad * 2, height: box.height.round() + pad * 2, numChannels: 4);
      final r = (color.r * 255).round(), g = (color.g * 255).round(), b = (color.b * 255).round();
      // Same color everywhere, so only the alpha fades at the blurred edge.
      im.fill(image, color: im.ColorRgba8(r, g, b, 0));
      im.fillRect(
        image,
        x1: pad,
        y1: pad,
        x2: pad + box.width.round(),
        y2: pad + box.height.round(),
        color: im.ColorRgba8(r, g, b, (color.a * 255).round()),
        radius: radius,
        alphaBlend: false,
      );
      context.canvas.drawImage(
        PdfImage.fromImage(context.document, image: im.gaussianBlur(image, radius: blur)),
        box.left + offset - pad,
        box.bottom - offset - pad,
      );
    }
    paintChild(context);
  }
}
