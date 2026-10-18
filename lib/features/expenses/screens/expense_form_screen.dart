import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/expense_validator.dart';
import '../../../data/services/permission_policy.dart';
import '../../groups/group_providers.dart';

enum _EntryMode { itemized, singleAmount }

/// Add a new expense, or edit one the signed-in user created.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.groupId, this.expenseId});

  final String groupId;

  /// Set when editing.
  final String? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ItemRow {
  _ItemRow({this.id = '', String name = '', String quantity = '1', String price = ''})
    : name = TextEditingController(text: name),
      quantity = TextEditingController(text: quantity),
      price = TextEditingController(text: price);

  final String id;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController price;

  int? get quantityMilli => Quantity.tryParse(quantity.text);
  int? get pricePaisa => Money.tryParse(price.text);

  int? get lineTotal {
    final q = quantityMilli;
    final p = pricePaisa;
    if (q == null || p == null) return null;
    return Quantity.lineTotal(unitPricePaisa: p, quantityMilli: q);
  }

  ExpenseItem toItem() =>
      ExpenseItem(id: id, name: name.text.trim(), quantityMilli: quantityMilli ?? 0, unitPricePaisa: pricePaisa ?? 0);

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final List<_ItemRow> _items = [];

  bool _initialized = false;
  bool _busy = false;
  DateTime _date = today();
  ExpenseCategory _category = ExpenseCategory.groceries;
  _EntryMode _mode = _EntryMode.singleAmount;
  PaymentSource _source = PaymentSource.personal;
  String? _paidBy;
  Set<String> _split = {};
  bool _splitTouched = false;

  bool get _isEditing => widget.expenseId != null;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }

  void _initFrom(GroupSnapshot s) {
    _initialized = true;
    final existing = widget.expenseId == null ? null : s.expenseById(widget.expenseId!);
    if (existing == null) {
      _paidBy = s.viewerUserId;
      _split = s.membersCoveringDay(_date).map((m) => m.userId).toSet();
      return;
    }
    _title.text = existing.title;
    _date = existing.date;
    _category = existing.category;
    _source = existing.paymentSource;
    _paidBy = existing.paidByUserId ?? s.viewerUserId;
    _split = existing.splitAmongUserIds.toSet();
    _splitTouched = true;
    _notes.text = existing.notes ?? '';
    if (existing.isItemized) {
      _mode = _EntryMode.itemized;
      for (final item in existing.items) {
        _items.add(
          _ItemRow(
            id: item.id,
            name: item.name,
            quantity: Quantity.format(item.quantityMilli),
            price: Money.toInput(item.unitPricePaisa),
          ),
        );
      }
    } else {
      _mode = _EntryMode.singleAmount;
      _amount.text = Money.toInput(existing.quickAmountPaisa ?? 0);
    }
  }

  int get _total {
    if (_mode == _EntryMode.singleAmount) return Money.tryParse(_amount.text) ?? 0;
    return _items.fold(0, (sum, row) => sum + (row.lineTotal ?? 0));
  }

  ExpenseDraft _draft() {
    final itemized = _mode == _EntryMode.itemized;
    return ExpenseDraft(
      title: _title.text,
      date: _date,
      category: _category,
      items: itemized ? _items.map((r) => r.toItem()).toList() : const [],
      quickAmountPaisa: itemized ? null : Money.tryParse(_amount.text),
      paidByUserId: _source == PaymentSource.personal ? _paidBy : null,
      paymentSource: _source,
      splitAmongUserIds: _split.toList(),
      notes: _notes.text,
    );
  }

  Future<void> _pickDate(GroupSnapshot s) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: today(),
      helpText: 'Expense date',
    );
    if (picked == null) return;
    setState(() {
      _date = dateOnly(picked);
      final eligible = s.membersCoveringDay(_date).map((m) => m.userId).toSet();
      _split = _splitTouched ? _split.intersection(eligible) : eligible;
      if (_paidBy != null && !eligible.contains(_paidBy)) {
        _paidBy = eligible.contains(s.viewerUserId) ? s.viewerUserId : (eligible.isEmpty ? null : eligible.first);
      }
    });
  }

  Future<void> _review(GroupSnapshot s) async {
    final fieldsOk = _formKey.currentState!.validate();
    final draft = _draft();
    final problems = ExpenseValidator.problems(draft);
    if (!fieldsOk || problems.isNotEmpty) {
      showAppSnack(context, problems.isNotEmpty ? problems.first : 'Please fix the highlighted fields.', isError: true);
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _ReviewSheet(draft: draft, snapshot: s, isEditing: _isEditing),
    );
    if (confirmed == true) await _save(s, draft);
  }

  Future<void> _save(GroupSnapshot s, ExpenseDraft draft) async {
    setState(() => _busy = true);
    final repo = ref.read(expenseRepositoryProvider);
    try {
      if (_isEditing) {
        await repo.updateExpense(actorUserId: s.viewerUserId, expenseId: widget.expenseId!, draft: draft);
      } else {
        await repo.addExpense(actorUserId: s.viewerUserId, groupId: s.group.id, draft: draft);
      }
      if (!mounted) return;
      context.pop();
      showAppSnack(context, _isEditing ? 'Expense updated' : 'Expense added');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether the signed-in user may use this form at all.
  bool _allowed(GroupSnapshot s) {
    if (!_isEditing) return PermissionPolicy.canAddExpense(s.me);
    final existing = s.expenseById(widget.expenseId!);
    return existing != null && PermissionPolicy.canEditExpense(actor: s.me, expense: existing);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(groupSnapshotProvider(widget.groupId));
    final allowed = snapshot.hasValue && _allowed(snapshot.requireValue);
    return Scaffold(
      appBar: NeuHeader(title: _isEditing ? 'Edit expense' : 'Add expense'),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (s) {
          if (_isEditing) {
            final existing = s.expenseById(widget.expenseId!);
            if (existing == null) return const ErrorView(error: NotFoundException('Expense not found.'));
            // Guards deep links too: the edit form is only for the creator.
            if (!PermissionPolicy.canEditExpense(actor: s.me, expense: existing)) {
              return ErrorView(
                error: PermissionDeniedException(
                  existing.isVoided
                      ? 'Voided expenses can\'t be changed.'
                      : 'Only ${s.nameOf(existing.createdByUserId)}, who added this expense, can edit it.',
                ),
              );
            }
          } else if (!PermissionPolicy.canAddExpense(s.me)) {
            return const ErrorView(error: PermissionDeniedException('You are not an active member of this group.'));
          }
          if (!_initialized) _initFrom(s);
          return _form(context, s);
        },
      ),
      bottomNavigationBar: allowed
          ? BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: context.text.labelMedium?.copyWith(color: context.appColors.muted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AmountText(
                            _total,
                            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: BusyButton(
                      label: 'Review & save',
                      busy: _busy,
                      onPressed: () => _review(snapshot.requireValue),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  /// The group fund pays whenever it has enough money; otherwise a person
  /// pays. An edit keeps how the expense was paid.
  PaymentSource _sourceFor(Expense? existing, int fundAvailable) {
    if (existing != null) return existing.paymentSource;
    return fundAvailable > 0 && _total <= fundAvailable ? PaymentSource.groupFund : PaymentSource.personal;
  }

  void _useItems() => setState(() {
    _mode = _EntryMode.itemized;
    if (_items.isEmpty) _items.add(_ItemRow());
  });

  void _useTotal() => setState(() {
    final itemsTotal = _items.fold(0, (sum, row) => sum + (row.lineTotal ?? 0));
    if (_amount.text.trim().isEmpty && itemsTotal > 0) _amount.text = Money.toInput(itemsTotal);
    _mode = _EntryMode.singleAmount;
  });

  Widget _form(BuildContext context, GroupSnapshot s) {
    final palette = NeuPalette.of(context);
    final eligible = s.membersCoveringDay(_date);
    final eligibleIds = eligible.map((m) => m.userId).toSet();
    final fund = BalanceCalculator.fundStatus(expenses: s.expenses, contributions: s.contributions);
    final existing = _isEditing ? s.expenseById(widget.expenseId!) : null;
    final fundAvailable =
        fund.remainingPaisa +
        (existing != null && !existing.isVoided && existing.paymentSource == PaymentSource.groupFund
            ? existing.totalPaisa
            : 0);
    _source = _sourceFor(existing, fundAvailable);
    final shares = BalanceCalculator.splitEqually(_total, _split);
    final excluded = s.members.where((m) => !eligibleIds.contains(m.userId) && m.isActive).toList();
    final allSelected = _split.length == eligibleIds.length;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          NeuTextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: ExpenseValidator.maxTitleLength,
            decoration: const InputDecoration(
              labelText: 'What was it?',
              hintText: 'e.g. Weekly groceries',
              counterText: '',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Say what it was for' : null,
          ),
          const SizedBox(height: 16),
          if (_mode == _EntryMode.singleAmount) ...[
            NeuTextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'How much?', prefixText: 'PKR '),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (_mode != _EntryMode.singleAmount) return null;
                final paisa = Money.tryParse(v ?? '');
                if (paisa == null) return 'Enter the amount';
                if (paisa <= 0) return 'Amount must be more than zero';
                return null;
              },
            ),
            _ModeLink(
              icon: Icons.format_list_bulleted_rounded,
              label: 'List items one by one (optional)',
              onTap: _useItems,
            ),
          ] else ...[
            for (final row in _items)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: 16),
                child: _ItemEditor(
                  row: row,
                  canRemove: _items.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    _items.remove(row);
                    row.dispose();
                  }),
                ),
              ),
            NeuButton(
              label: 'Add another item',
              icon: Icons.add_rounded,
              primary: false,
              height: 48,
              onPressed: () => setState(() => _items.add(_ItemRow())),
            ),
            _ModeLink(icon: Icons.payments_outlined, label: 'Enter one total instead', onTap: _useTotal),
          ],
          const SizedBox(height: 12),
          NeuPickerField(label: 'Date', value: AppDates.day(_date), onTap: () => _pickDate(s)),
          const NeuSectionLabel('Category'),
          NeuChipGrid(
            children: [
              for (final c in ExpenseCategory.values)
                NeuChip(
                  expand: true,
                  leading: Icon(c.icon, size: 16, color: c.color),
                  label: c.label,
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const NeuSectionLabel('Who paid?'),
          if (_source == PaymentSource.groupFund)
            _FundNotice(available: fundAvailable, total: _total)
          else ...[
            if (fundAvailable > 0 && existing == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Text(
                  'The group fund has only ${Money.format(fundAvailable, roundToRupee: true)} left, '
                  'so a person pays for this one.',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ),
            NeuChipGrid(
              columns: 2,
              children: [
                for (final m in eligible)
                  NeuChip(
                    expand: true,
                    leading: MemberAvatar(name: m.displayName, size: 26),
                    label: m.userId == s.viewerUserId ? 'You' : m.displayName,
                    selected: _paidBy == m.userId,
                    onTap: () => setState(() => _paidBy = m.userId),
                  ),
              ],
            ),
          ],
          NeuSectionLabel(
            'Who shares it?',
            trailing: GestureDetector(
              onTap: () => setState(() {
                Haptics.tap();
                _splitTouched = true;
                _split = allSelected ? {} : {...eligibleIds};
              }),
              child: Text(
                allSelected ? 'Clear' : 'Select all',
                style: TextStyle(color: palette.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          NeuChipGrid(
            columns: 2,
            children: [
              for (final m in eligible)
                NeuChip(
                  expand: true,
                  leading: Icon(
                    _split.contains(m.userId) ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 18,
                    color: _split.contains(m.userId) ? palette.accent : palette.muted,
                  ),
                  label:
                      '${m.userId == s.viewerUserId ? 'You' : m.displayName.split(' ').first}'
                      '${_split.contains(m.userId) && _total > 0 ? ' · ${Money.format(shares[m.userId] ?? 0, roundToRupee: true)}' : ''}',
                  selected: _split.contains(m.userId),
                  onTap: () => setState(() {
                    _splitTouched = true;
                    _split.contains(m.userId) ? _split.remove(m.userId) : _split.add(m.userId);
                  }),
                ),
            ],
          ),
          if (excluded.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${excluded.map((m) => m.displayName.split(' ').first).join(', ')} joined later, so not included.',
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
            ),
          ],
          const SizedBox(height: 22),
          NeuTextFormField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
    );
  }
}

/// A small text link that switches between one total and a list of items.
class _ModeLink extends StatelessWidget {
  const _ModeLink({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = NeuPalette.of(context).accent;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of "who paid" when the group fund covers the expense.
class _FundNotice extends StatelessWidget {
  const _FundNotice({required this.available, required this.total});

  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final short = total > available;
    return NeuBox(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          const NeuIconDisc(icon: Icons.savings_rounded, color: NeuHues.violet, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paid from the group fund',
                  style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
                ),
                Text(
                  short
                      ? 'Only ${Money.format(available, roundToRupee: true)} left in the fund'
                      : '${Money.format(available, roundToRupee: true)} left in the fund',
                  style: TextStyle(fontSize: 12.5, color: short ? context.appColors.negative : palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One item: name, then quantity × price with the line total.
class _ItemEditor extends StatelessWidget {
  const _ItemEditor({required this.row, required this.canRemove, required this.onChanged, required this.onRemove});

  final _ItemRow row;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final line = row.lineTotal;
    return NeuBox(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: NeuTextFormField(
                  controller: row.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Item name', isDense: true),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 10),
                NeuIconButton(icon: Icons.close_rounded, tooltip: 'Remove item', size: 38, onPressed: onRemove),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: NeuTextFormField(
                  controller: row.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  validator: (v) {
                    final q = Quantity.tryParse(v ?? '');
                    if (q == null) return 'Invalid';
                    if (q <= 0) return 'Above 0';
                    return null;
                  },
                  onChanged: (_) => onChanged(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                child: Text('×', style: TextStyle(color: palette.muted)),
              ),
              Expanded(
                child: NeuTextFormField(
                  controller: row.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price each', prefixText: 'PKR ', isDense: true),
                  validator: (v) => Money.tryParse(v ?? '') == null ? 'Invalid price' : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          if (line != null && line > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Row(
                children: [
                  Text('Item total', style: TextStyle(fontSize: 12.5, color: palette.muted)),
                  const Spacer(),
                  AmountText(line, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Summary shown before saving, as the spec asks.
class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.draft, required this.snapshot, required this.isEditing});

  final ExpenseDraft draft;
  final GroupSnapshot snapshot;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final shares = BalanceCalculator.splitEqually(draft.totalPaisa, draft.splitAmongUserIds);
    final muted = context.appColors.muted;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  Text(
                    isEditing ? 'Review changes' : 'Review expense',
                    style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CategoryIcon(draft.category),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.title.trim(),
                              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${draft.category.label}  ·  ${AppDates.day(draft.date)}',
                              style: context.text.bodySmall?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (draft.isItemized)
                    for (final item in draft.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.name.trim())),
                            Text(
                              '${Quantity.format(item.quantityMilli)} × ${Money.format(item.unitPricePaisa, withCurrency: false)}',
                              style: TextStyle(color: muted),
                            ),
                            const SizedBox(width: 12),
                            AmountText(item.lineTotalPaisa),
                          ],
                        ),
                      ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      AmountText(
                        draft.totalPaisa,
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _line(
                    context,
                    'Paid by',
                    draft.paymentSource == PaymentSource.groupFund ? 'Group fund' : snapshot.nameOf(draft.paidByUserId),
                  ),

                  const SizedBox(height: 8),
                  Text('Each person\'s share', style: context.text.labelLarge),
                  const SizedBox(height: 4),
                  for (final entry in shares.entries)
                    _line(context, snapshot.nameOf(entry.key), Money.format(entry.value)),
                  if ((draft.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _line(context, 'Notes', draft.notes!.trim()),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: NeuButton(
                      label: 'Keep editing',
                      primary: false,
                      height: 52,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NeuButton(
                      label: isEditing ? 'Save changes' : 'Save expense',
                      height: 52,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: context.appColors.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
