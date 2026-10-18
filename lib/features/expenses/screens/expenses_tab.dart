import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';
import '../../../data/services/permission_policy.dart';
import '../widgets/expense_tile.dart';

/// What the expense list is narrowed to. All time, every category and
/// everyone by default.
class _Filters {
  const _Filters({this.period = const PeriodFilter(PeriodPreset.allTime), this.category, this.memberUserId});

  final PeriodFilter period;
  final ExpenseCategory? category;

  /// Someone who added or paid the expense.
  final String? memberUserId;

  bool get hasPeriod => period.preset != PeriodPreset.allTime;
  int get count => (hasPeriod ? 1 : 0) + (category == null ? 0 : 1) + (memberUserId == null ? 0 : 1);

  _Filters withPeriod(PeriodFilter value) => _Filters(period: value, category: category, memberUserId: memberUserId);
  _Filters withCategory(ExpenseCategory? value) =>
      _Filters(period: period, category: value, memberUserId: memberUserId);
  _Filters withMember(String? value) => _Filters(period: period, category: category, memberUserId: value);

  bool matches(Expense e, String query) {
    final range = period.resolve();
    if (range != null && !range.contains(e.date)) return false;
    if (category != null && e.category != category) return false;
    if (memberUserId != null && e.createdByUserId != memberUserId && e.paidByUserId != memberUserId) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.title.toLowerCase().contains(q) ||
        e.items.any((item) => item.name.toLowerCase().contains(q)) ||
        (e.notes?.toLowerCase().contains(q) ?? false);
  }
}

/// Full expense history: search, one filter button, and the list by day.
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _search = TextEditingController();
  _Filters _filters = const _Filters();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(snapshot: widget.snapshot, initial: _filters, query: _search.text),
    );
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final palette = NeuPalette.of(context);
    final filtered = s.expenses.where((e) => _filters.matches(e, _search.text)).toList();
    final total = filtered.where((e) => !e.isVoided).fold(0, (sum, e) => sum + e.totalPaisa);
    final days = <DateTime, List<Expense>>{};
    for (final e in filtered) {
      days.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }
    final canAdd = PermissionPolicy.canAddExpense(s.me);

    return Scaffold(
      appBar: NeuHeader(
        title: 'Expenses',
        caption: '${filtered.length} ${filtered.length == 1 ? 'expense' : 'expenses'} · ${Money.format(total)}',
        showBack: false,
      ),
      // A plain clay "+" in the middle, above the tabs.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: canAdd
          ? NeuIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Add expense',
              size: 64,
              color: palette.text,
              onPressed: () => context.push(Routes.addExpense(s.group.id)),
            )
          : null,
      body: ListView(
        // Room at the bottom so the last expense isn't under the button.
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: NeuTextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search expenses',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Badge(
                isLabelVisible: _filters.count > 0,
                label: Text('${_filters.count}'),
                backgroundColor: NeuHues.coral,
                child: NeuIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filter',
                  size: 52,
                  color: _filters.count > 0 ? NeuHues.coral : palette.muted,
                  onPressed: _openFilters,
                ),
              ),
            ],
          ),
          if (_filters.count > 0) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_filters.hasPeriod)
                  _ActiveFilter(
                    label: _filters.period.preset == PeriodPreset.custom
                        ? _filters.period.describe()
                        : _filters.period.preset.label,
                    onRemove: () =>
                        setState(() => _filters = _filters.withPeriod(const PeriodFilter(PeriodPreset.allTime))),
                  ),
                if (_filters.category != null)
                  _ActiveFilter(
                    label: _filters.category!.label,
                    onRemove: () => setState(() => _filters = _filters.withCategory(null)),
                  ),
                if (_filters.memberUserId != null)
                  _ActiveFilter(
                    label: s.nameOf(_filters.memberUserId),
                    onRemove: () => setState(() => _filters = _filters.withMember(null)),
                  ),
                GestureDetector(
                  onTap: () {
                    Haptics.tap();
                    setState(() => _filters = const _Filters());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Clear all',
                      style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: s.expenses.isEmpty ? Icons.receipt_long_outlined : Icons.search_off_rounded,
                title: s.expenses.isEmpty ? 'No expenses yet' : 'Nothing matches',
                message: s.expenses.isEmpty
                    ? 'Tap "Add expense" to add the first one.'
                    : 'Try another search or clear the filters.',
              ),
            ),
          for (final entry in days.entries) ...[
            NeuSectionLabel(
              AppDates.relativeDay(entry.key),
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 12),
              trailing: AmountText(
                entry.value.where((e) => !e.isVoided).fold(0, (sum, e) => sum + e.totalPaisa),
                style: TextStyle(color: palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            for (final e in entry.value) ExpenseTile(expense: e, snapshot: s),
          ],
        ],
      ),
    );
  }
}

/// A filter in use, with an × to drop it.
class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return NeuPressable(
      onTap: onRemove,
      radius: 16,
      depth: 3,
      semanticLabel: 'Remove filter $label',
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: NeuHues.coral, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.close_rounded, size: 16, color: NeuHues.coral),
        ],
      ),
    );
  }
}

/// Period, category and person in one sheet; the button shows how many
/// expenses the choice leaves.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.snapshot, required this.initial, required this.query});

  final GroupSnapshot snapshot;
  final _Filters initial;
  final String query;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Filters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final palette = NeuPalette.of(context);
    final people = <String, String>{};
    for (final m in [...s.activeMembers, ...s.formerMembers]) {
      people.putIfAbsent(m.userId, () => m.displayName);
    }
    final count = s.expenses.where((e) => _draft.matches(e, widget.query)).length;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Filter expenses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: palette.text),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NeuSectionLabel('When', padding: EdgeInsets.fromLTRB(6, 18, 6, 12)),
                  PeriodSelector(
                    wrap: true,
                    padding: EdgeInsets.zero,
                    value: _draft.period,
                    presets: const [
                      PeriodPreset.allTime,
                      PeriodPreset.thisMonth,
                      PeriodPreset.last15Days,
                      PeriodPreset.last10Days,
                      PeriodPreset.custom,
                    ],
                    onChanged: (p) => setState(() => _draft = _draft.withPeriod(p)),
                  ),
                  const NeuSectionLabel('Category', padding: EdgeInsets.fromLTRB(6, 24, 6, 12)),
                  NeuChipGrid(
                    children: [
                      NeuChip(
                        label: 'All',
                        expand: true,
                        leading: Icon(Icons.apps_rounded, size: 16, color: palette.muted),
                        selected: _draft.category == null,
                        onTap: () => setState(() => _draft = _draft.withCategory(null)),
                      ),
                      for (final c in ExpenseCategory.values)
                        NeuChip(
                          label: c.label,
                          expand: true,
                          leading: Icon(c.icon, size: 16, color: c.color),
                          selected: _draft.category == c,
                          onTap: () => setState(() => _draft = _draft.withCategory(c)),
                        ),
                    ],
                  ),
                  const NeuSectionLabel('Added or paid by', padding: EdgeInsets.fromLTRB(6, 24, 6, 12)),
                  // Two per row so names have room.
                  NeuChipGrid(
                    columns: 2,
                    children: [
                      NeuChip(
                        label: 'Everyone',
                        expand: true,
                        leading: Icon(Icons.groups_rounded, size: 20, color: palette.muted),
                        selected: _draft.memberUserId == null,
                        onTap: () => setState(() => _draft = _draft.withMember(null)),
                      ),
                      for (final MapEntry(key: id, value: name) in people.entries)
                        NeuChip(
                          label: id == s.viewerUserId ? 'You' : name,
                          expand: true,
                          leading: MemberAvatar(name: name, size: 26),
                          selected: _draft.memberUserId == id,
                          onTap: () => setState(() => _draft = _draft.withMember(id)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: Row(
              children: [
                Expanded(
                  child: NeuButton(
                    label: 'Clear',
                    primary: false,
                    height: 52,
                    onPressed: () => setState(() => _draft = const _Filters()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: NeuButton(
                    label: 'Show $count ${count == 1 ? 'expense' : 'expenses'}',
                    height: 52,
                    onPressed: () => Navigator.of(context).pop(_draft),
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
