import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/quantity.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
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
  _EntryMode _mode = _EntryMode.itemized;
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
      _items.add(_ItemRow());
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
      _items.add(_ItemRow());
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
      showAppSnack(context, _isEditing ? 'Expense updated' : 'Expense added for everyone in the group');
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit expense' : 'Add expense')),
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

  Widget _form(BuildContext context, GroupSnapshot s) {
    final eligible = s.membersCoveringDay(_date);
    final eligibleIds = eligible.map((m) => m.userId).toSet();
    final fund = BalanceCalculator.fundStatus(expenses: s.expenses, contributions: s.contributions);
    final existing = _isEditing ? s.expenseById(widget.expenseId!) : null;
    final fundAvailable =
        fund.remainingPaisa +
        (existing != null && !existing.isVoided && existing.paymentSource == PaymentSource.groupFund
            ? existing.totalPaisa
            : 0);
    final shares = BalanceCalculator.splitEqually(_total, _split);
    final excluded = s.members.where((m) => !eligibleIds.contains(m.userId) && m.isActive).toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_isEditing && existing != null) ...[
            InfoBanner(
              icon: Icons.edit_note,
              message:
                  'You added this expense, so you can correct it. '
                  'It will be marked "Edited" for everyone in the group.',
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: ExpenseValidator.maxTitleLength,
            decoration: const InputDecoration(
              labelText: 'Title or short description',
              hintText: 'e.g. Weekly groceries',
              counterText: '',
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Add a title' : null,
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickDate(s),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(AppDates.day(_date)),
            ),
          ),
          const SectionHeader('Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ExpenseCategory.values)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 18, color: _category == c ? context.colors.onSecondaryContainer : c.color),
                  label: Text(c.label),
                  selected: _category == c,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SectionHeader('Amount'),
          SegmentedButton<_EntryMode>(
            segments: const [
              ButtonSegment(value: _EntryMode.itemized, label: Text('Itemized'), icon: Icon(Icons.list_alt)),
              ButtonSegment(
                value: _EntryMode.singleAmount,
                label: Text('Single amount'),
                icon: Icon(Icons.payments_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 12),
          if (_mode == _EntryMode.itemized) ...[
            for (final (index, row) in _items.indexed)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemEditor(
                  row: row,
                  index: index,
                  canRemove: _items.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    _items.remove(row);
                    row.dispose();
                  }),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _items.add(_ItemRow())),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
            const SizedBox(height: 6),
            Text(
              'Line total = quantity × price per item. Quantities can have decimals, e.g. 1.5 kg.',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ] else
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total amount', prefixText: 'PKR '),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (_mode != _EntryMode.singleAmount) return null;
                final paisa = Money.tryParse(v ?? '');
                if (paisa == null) return 'Enter a valid amount';
                if (paisa <= 0) return 'Amount must be more than zero';
                return null;
              },
            ),
          const SectionHeader('Payment'),
          SegmentedButton<PaymentSource>(
            segments: const [
              ButtonSegment(
                value: PaymentSource.personal,
                label: Text('Personal money'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: PaymentSource.groupFund,
                label: Text('Group fund'),
                icon: Icon(Icons.savings_outlined),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (v) => setState(() => _source = v.first),
          ),
          const SizedBox(height: 12),
          if (_source == PaymentSource.personal) ...[
            Text('Who paid?', style: context.text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in eligible)
                  ChoiceChip(
                    avatar: MemberAvatar(name: m.displayName, size: 24),
                    label: Text(m.userId == s.viewerUserId ? 'You' : m.displayName),
                    selected: _paidBy == m.userId,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _paidBy = m.userId),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You are recorded as the person who added this expense, even if someone else paid.',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ] else
            InfoBanner(
              tone: _total > fundAvailable ? BannerTone.warning : BannerTone.fund,
              message: _total > fundAvailable
                  ? 'This is more than the ${Money.format(fundAvailable)} left in the group fund.'
                  : 'Paid from the group fund. ${Money.format(fundAvailable)} available.',
            ),
          SectionHeader(
            'Shared between',
            trailing: TextButton(
              onPressed: () => setState(() {
                _splitTouched = true;
                _split = _split.length == eligibleIds.length ? {} : {...eligibleIds};
              }),
              child: Text(_split.length == eligibleIds.length ? 'Clear' : 'Select all'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in eligible)
                FilterChip(
                  label: Text(
                    '${m.userId == s.viewerUserId ? 'You' : m.displayName.split(' ').first}'
                    '${_split.contains(m.userId) && _total > 0 ? '  ${Money.format(shares[m.userId] ?? 0)}' : ''}',
                  ),
                  selected: _split.contains(m.userId),
                  onSelected: (selected) => setState(() {
                    _splitTouched = true;
                    selected ? _split.add(m.userId) : _split.remove(m.userId);
                  }),
                ),
            ],
          ),
          if (excluded.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${excluded.map((m) => m.displayName).join(', ')} joined after ${AppDates.day(_date)}, '
              'so they don\'t share this expense.',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ],
          const SectionHeader('Notes (optional)'),
          TextFormField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: 'Anything the group should know'),
          ),
        ],
      ),
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _ItemRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final line = row.lineTotal;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: context.text.labelLarge?.copyWith(color: context.appColors.muted),
                ),
              ),
              Text(
                line == null ? '—' : Money.format(line),
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove this item row',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                TextFormField(
                  controller: row.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Item name', isDense: true),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
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
                    const Padding(padding: EdgeInsets.fromLTRB(8, 12, 8, 0), child: Text('×')),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: row.price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price each', prefixText: 'PKR ', isDense: true),
                        validator: (v) => Money.tryParse(v ?? '') == null ? 'Invalid price' : null,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
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
                  _line(context, 'Payment source', draft.paymentSource.label),
                  _line(context, 'Added by', snapshot.nameOf(snapshot.viewerUserId)),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep editing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(isEditing ? 'Save changes' : 'Save expense'),
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
          Flexible(
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
