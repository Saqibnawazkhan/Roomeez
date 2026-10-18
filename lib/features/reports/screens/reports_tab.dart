import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';

/// Choose a period, see a quick summary, and create the PDF.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const _presets = [PeriodPreset.thisMonth, PeriodPreset.last15Days, PeriodPreset.last10Days];

  PeriodFilter _period = const PeriodFilter.thisMonth();

  Future<void> _pickDay({required bool start}) async {
    final range = _period.resolve()!;
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? range.start : range.end,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: start ? 'Start date' : 'End date',
    );
    if (picked == null) return;
    var newStart = start ? picked : range.start;
    var newEnd = start ? range.end : picked;
    if (newEnd.isBefore(newStart)) {
      if (start) {
        newEnd = newStart;
      } else {
        newStart = newEnd;
      }
    }
    setState(() => _period = PeriodFilter(PeriodPreset.custom, customRange: DateRange(newStart, newEnd)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final range = _period.resolve()!;
    final summary = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
      range: range,
    );

    return Scaffold(
      appBar: const NeuHeader(title: 'Reports', caption: 'PDF for any period', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          PeriodSelector(
            value: _period,
            presets: _presets,
            wrap: true,
            padding: EdgeInsets.zero,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NeuPickerField(
                  label: 'From',
                  value: AppDates.day(range.start),
                  icon: Icons.event_rounded,
                  onTap: () => _pickDay(start: true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: NeuPickerField(
                  label: 'To',
                  value: AppDates.day(range.end),
                  icon: Icons.event_rounded,
                  onTap: () => _pickDay(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SummaryCard(range: range, summary: summary),
          const NeuSectionLabel('Where the money went'),
          _CategoryBreakdown(summary: summary),
          const NeuSectionLabel("What's in the PDF"),
          const _PdfContents(),
          const SizedBox(height: 24),
          BusyButton(
            label: 'Create PDF report',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: () => context.push(Routes.report(s.group.id, range)),
          ),
        ],
      ),
    );
  }
}

/// The chosen period and its totals, in the reports' amber.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.range, required this.summary});

  final DateRange range;
  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.85);
    final days = range.dayCount;
    return NeuBox(
      radius: 28,
      gradient: NeuHues.gradient(NeuHues.amber),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPORT PERIOD',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: soft),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppDates.range(range),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
          Text('$days ${days == 1 ? 'day' : 'days'}', style: TextStyle(color: soft, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _Stat(label: 'Spent', value: Money.format(summary.totalExpensesPaisa, roundToRupee: true)),
                _Stat(label: 'Expenses', value: '${summary.expenseCount}'),
                _Stat(
                  label: 'Per day',
                  value: Money.format((summary.totalExpensesPaisa + days ~/ 2) ~/ days, roundToRupee: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// The biggest categories with a colored bar each.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final entries = summary.byCategory.take(4).toList();
    if (entries.isEmpty) {
      return NeuBox(
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Text(
          'Nothing was spent in this period.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.muted),
        ),
      );
    }
    final total = summary.totalExpensesPaisa == 0 ? 1 : summary.totalExpensesPaisa;
    return NeuBox(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      child: Column(
        children: [
          for (final (i, MapEntry(key: category, value: paisa)) in entries.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                CategoryIcon(category, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.label,
                              style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
                            ),
                          ),
                          AmountText(
                            paisa,
                            roundToRupee: true,
                            style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      NeuBox(
                        style: NeuStyle.inset,
                        radius: 5,
                        height: 10,
                        padding: const EdgeInsets.all(2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (paisa / total).clamp(0.03, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(4)),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A glance at what the one-page PDF holds.
class _PdfContents extends StatelessWidget {
  const _PdfContents();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.payments_rounded, 'Totals', NeuHues.teal),
      (Icons.balance_rounded, 'Balances', NeuHues.indigo),
      (Icons.pie_chart_rounded, 'Categories', NeuHues.amber),
      (Icons.receipt_long_rounded, 'Expenses', NeuHues.coral),
    ];
    return Row(
      children: [
        for (final (icon, label, hue) in items)
          Expanded(
            child: Column(
              children: [
                NeuIconDisc(icon: icon, color: hue, size: 48),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NeuPalette.of(context).text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
