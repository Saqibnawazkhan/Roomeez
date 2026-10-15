import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';
import '../../../data/services/permission_policy.dart';
import '../widgets/expense_tile.dart';

/// Full expense history with search and filters.
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final _search = TextEditingController();
  PeriodFilter _period = const PeriodFilter(PeriodPreset.allTime);
  ExpenseCategory? _category;
  String? _memberUserId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Expense e, DateRange? range) {
    if (range != null && !range.contains(e.date)) return false;
    if (_category != null && e.category != _category) return false;
    if (_memberUserId != null && e.createdByUserId != _memberUserId && e.paidByUserId != _memberUserId) {
      return false;
    }

    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return e.title.toLowerCase().contains(query) ||
        e.items.any((item) => item.name.toLowerCase().contains(query)) ||
        (e.notes?.toLowerCase().contains(query) ?? false);
  }

  Future<T?> _pick<T>(String title, List<(T?, String, Widget?)> options, T? selected) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(title, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final (value, label, leading) in options)
                ListTile(
                  leading: leading,
                  title: Text(label),
                  trailing: value == selected ? Icon(Icons.check, color: context.colors.primary) : null,
                  // A null value means "All"; return a sentinel so the
                  // caller can tell it apart from dismissing the sheet.
                  onTap: () => Navigator.of(sheet).pop(value ?? _all),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const Object _all = Object();

  Future<void> _pickCategory() async {
    final result = await _pick<Object>('Category', [
      (null, 'All categories', const Icon(Icons.apps)),
      for (final c in ExpenseCategory.values) (c, c.label, CategoryIcon(c, size: 32)),
    ], _category);
    if (result == null) return;
    setState(() => _category = result == _all ? null : result as ExpenseCategory);
  }

  Future<void> _pickMember() async {
    final s = widget.snapshot;
    final people = <String, String>{};
    for (final m in [...s.activeMembers, ...s.formerMembers]) {
      people.putIfAbsent(m.userId, () => m.displayName);
    }
    final result = await _pick<Object>('Added or paid by', [
      (null, 'Everyone', const Icon(Icons.groups_outlined)),
      for (final entry in people.entries)
        (
          entry.key,
          entry.key == s.viewerUserId ? '${entry.value} (you)' : entry.value,
          MemberAvatar(name: entry.value, size: 32),
        ),
    ], _memberUserId);
    if (result == null) return;
    setState(() => _memberUserId = result == _all ? null : result as String);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final range = _period.resolve();
    final filtered = s.expenses.where((e) => _matches(e, range)).toList();
    final countedTotal = filtered.where((e) => !e.isVoided).fold(0, (sum, e) => sum + e.totalPaisa);

    final days = <DateTime, List<Expense>>{};
    for (final e in filtered) {
      days.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }
    final hasFilters = _category != null || _memberUserId != null || _search.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: PermissionPolicy.canAddExpense(s.me)
          ? FloatingActionButton.extended(
              heroTag: 'expenses-add',
              onPressed: () => context.push(Routes.addExpense(s.group.id)),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChipButton(
                  label: _category?.label ?? 'All categories',
                  active: _category != null,
                  onTap: _pickCategory,
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: _memberUserId == null ? 'All members' : s.nameOf(_memberUserId),
                  active: _memberUserId != null,
                  onTap: _pickMember,
                ),

                if (hasFilters) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _category = null;
                      _memberUserId = null;

                      _search.clear();
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '${filtered.length} ${filtered.length == 1 ? 'expense' : 'expenses'} · ${Money.format(countedTotal)}',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ),
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.search_off,
              title: s.expenses.isEmpty ? 'No expenses yet' : 'No matching expenses',
              message: s.expenses.isEmpty
                  ? 'Expenses added by any member appear here.'
                  : 'Try a different period, filter or search.',
            ),
          for (final entry in days.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppDates.relativeDay(entry.key),
                      style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AmountText(
                    entry.value.where((e) => !e.isVoided).fold(0, (sum, e) => sum + e.totalPaisa),
                    style: context.text.labelLarge?.copyWith(color: context.appColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (i, e) in entry.value.indexed) ...[
                      if (i > 0) const Divider(indent: 70),
                      ExpenseTile(expense: e, snapshot: s),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      onPressed: onTap,
      avatar: const Icon(Icons.filter_list, size: 18),
    );
  }
}
