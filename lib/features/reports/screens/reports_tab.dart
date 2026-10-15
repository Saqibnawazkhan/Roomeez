import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';

/// Choose a period and generate a report.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const _presets = [
    PeriodPreset.last10Days,
    PeriodPreset.last15Days,
    PeriodPreset.thisMonth,
    PeriodPreset.custom,
  ];

  PeriodFilter _period = const PeriodFilter(PeriodPreset.last15Days);

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
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PeriodSelector(value: _period, presets: _presets, onChanged: (p) => setState(() => _period = p)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateField(label: 'Start date', date: range.start, onTap: () => _pickDay(start: true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(label: 'End date', date: range.end, onTap: () => _pickDay(start: false)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${range.dayCount} days · ${summary.expenseCount} expenses',
                          style: TextStyle(color: context.appColors.muted),
                        ),
                      ),
                      AmountText(summary.totalExpensesPaisa, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BusyButton(
                  label: 'Generate report',
                  icon: Icons.description_outlined,
                  onPressed: () => context.push(Routes.report(s.group.id, range)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true, suffixIcon: const Icon(Icons.event, size: 20)),
        child: Text(AppDates.day(date), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
