import 'package:flutter/material.dart';

import '../neu/neu.dart';
import '../utils/dates.dart';

/// Horizontal preset chips with a "Custom" option that opens a date range
/// picker.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = PeriodPreset.values,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 14),
  });

  final PeriodFilter value;
  final ValueChanged<PeriodFilter> onChanged;
  final List<PeriodPreset> presets;
  final EdgeInsetsGeometry padding;

  Future<void> _pickCustom(BuildContext context) async {
    final now = today();
    final current = value.resolve() ?? DateRange(DateTime(now.year, now.month), now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      helpText: 'Select period',
      saveText: 'Apply',
    );
    if (picked == null) return;
    onChanged(PeriodFilter(PeriodPreset.custom, customRange: DateRange(picked.start, picked.end)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: NeuChip(
                label: preset == PeriodPreset.custom && value.preset == PeriodPreset.custom
                    ? AppDates.range(value.customRange!)
                    : preset.label,
                leading: preset == PeriodPreset.custom
                    ? Icon(Icons.date_range, size: 18, color: NeuPalette.of(context).muted)
                    : null,
                selected: value.preset == preset,
                onTap: () {
                  if (preset == PeriodPreset.custom) {
                    _pickCustom(context);
                  } else {
                    onChanged(PeriodFilter(preset));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
