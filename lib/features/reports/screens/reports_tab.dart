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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Create a report for any period to review or share with the group.',
              style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
            ),
          ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report period', style: context.text.labelLarge?.copyWith(color: context.appColors.muted)),
                      const SizedBox(height: 2),
                      Text(
                        '${AppDates.range(range)}  (${range.dayCount} days)',
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LabeledValue(label: 'Expenses', value: Text('${summary.expenseCount}')),
                          ),
                          Expanded(
                            child: LabeledValue(label: 'Total', value: AmountText(summary.totalExpensesPaisa)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BusyButton(
                  label: 'Generate report',
                  icon: Icons.description_outlined,
                  onPressed: () => context.push(Routes.report(s.group.id, range)),
                ),
                const SectionHeader('What\'s included'),
                AppCard(
                  child: Column(
                    children: const [
                      _Included(Icons.today_outlined, 'Daily expense list with items, quantities and prices'),
                      _Included(Icons.person_outline, 'Who added and who paid for each expense'),
                      _Included(Icons.savings_outlined, 'Group fund contributions, kept separate from expenses'),
                      _Included(Icons.groups_outlined, 'Members, their joining dates and balances for the period'),
                      _Included(Icons.functions, 'Summary totals'),
                    ],
                  ),
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

class _Included extends StatelessWidget {
  const _Included(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
