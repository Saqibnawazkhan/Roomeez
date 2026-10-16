import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/quantity.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';
import '../../groups/group_providers.dart';

/// Everyone in the group can view an expense. Only its creator sees the
/// Edit and Void controls. There is no way to erase an expense.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.groupId, required this.expenseId});

  final String groupId;
  final String expenseId;

  Future<void> _void(BuildContext context, WidgetRef ref, GroupSnapshot s, Expense e) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _VoidDialog());
    if (reason == null || !context.mounted) return;
    try {
      await ref
          .read(expenseRepositoryProvider)
          .voidExpense(actorUserId: s.viewerUserId, expenseId: e.id, reason: reason);
      if (context.mounted) showAppSnack(context, 'Expense voided');
    } catch (error) {
      if (context.mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(groupSnapshotProvider(groupId));
    return snapshot.when(
      loading: () => Scaffold(
        appBar: NeuHeader(title: ''),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: NeuHeader(title: ''),
        body: ErrorView(error: error),
      ),
      data: (s) {
        final e = s.expenseById(expenseId);
        if (e == null) {
          return Scaffold(
            appBar: NeuHeader(title: ''),
            body: const ErrorView(error: NotFoundException('This expense could not be found.')),
          );
        }
        final canEdit = PermissionPolicy.canEditExpense(actor: s.me, expense: e);
        return Scaffold(
          appBar: NeuHeader(
            title: 'Expense details',
            trailing: [
              if (canEdit)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) {
                    if (value == 'void') _void(context, ref, s, e);
                  },
                  child: NeuBox(
                    circle: true,
                    width: 46,
                    height: 46,
                    depth: 4.6,
                    child: Icon(Icons.more_horiz_rounded, color: NeuPalette.of(context).muted),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'void',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.block),
                        title: Text('Void expense'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: _body(context, s, e, canEdit),
          bottomNavigationBar: canEdit
              ? BottomActionBar(
                  child: BusyButton(
                    label: 'Edit expense',
                    icon: Icons.edit_outlined,
                    onPressed: () => context.push(Routes.editExpense(groupId, expenseId)),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupSnapshot s, Expense e, bool canEdit) {
    final muted = context.appColors.muted;
    final creator = s.nameOf(e.createdByUserId);
    final creatorActive = s.activeMembershipOf(e.createdByUserId) != null;
    final shares = BalanceCalculator.shares(e);
    final labelStyle = TextStyle(color: muted, fontSize: 12.5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryIcon(e.category, size: 44, muted: e.isVoided),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: e.isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          '${e.category.label} · ${AppDates.day(e.date)}',
                          style: context.text.bodyMedium?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AmountText(
                      e.totalPaisa,
                      strikethrough: e.isVoided,
                      style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w300),
                    ),
                  ),
                  if (e.isVoided)
                    Pill('Voided', color: context.colors.error)
                  else if (e.isEdited)
                    Pill('Edited', color: context.colors.tertiary),
                ],
              ),
            ],
          ),
        ),
        if (e.isVoided) ...[
          const SizedBox(height: 12),
          InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.block,
            message: 'Voided: ${e.voidReason}. Not counted in totals.',
          ),
        ] else if (!canEdit) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  creatorActive
                      ? 'Only $creator can edit this expense.'
                      : '$creator has left, so this can\'t be edited.',
                  style: context.text.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
        if (e.isItemized) ...[
          const SectionHeader('Items'),
          NeuBox(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: Text('Item', style: labelStyle)),
                        Expanded(
                          flex: 2,
                          child: Text('Qty', textAlign: TextAlign.right, style: labelStyle),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Price', textAlign: TextAlign.right, style: labelStyle),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Total', textAlign: TextAlign.right, style: labelStyle),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  for (final item in e.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: Text(item.name)),
                          Expanded(
                            flex: 2,
                            child: Text(Quantity.format(item.quantityMilli), textAlign: TextAlign.right),
                          ),
                          Expanded(
                            flex: 3,
                            child: AmountText(item.unitPricePaisa, withCurrency: false, textAlign: TextAlign.right),
                          ),
                          Expanded(
                            flex: 3,
                            child: AmountText(item.lineTotalPaisa, withCurrency: false, textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SectionHeader('Details'),
        AppCard(
          child: Column(
            children: [
              _row(context, 'Added by', creator),
              _row(
                context,
                'Paid by',
                e.paymentSource == PaymentSource.groupFund ? 'Group fund' : s.nameOf(e.paidByUserId),
              ),
              if (e.isEdited) _row(context, 'Last edited', AppDates.dateTime(e.editedAt!)),
              if (e.notes != null) _row(context, 'Note', e.notes!),
            ],
          ),
        ),
        SectionHeader(shares.length == 1 ? 'For 1 person' : 'Split among ${shares.length} people'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final entry in shares.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      MemberAvatar(name: s.nameOf(entry.key), size: 30),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.key == s.viewerUserId ? 'You' : s.nameOf(entry.key))),
                      AmountText(entry.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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

class _VoidDialog extends StatefulWidget {
  const _VoidDialog();

  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Void this expense?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('It stays visible but won\'t count in totals. This can\'t be undone.'),
          const SizedBox(height: 14),
          NeuTextField(
            controller: _reason,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Entered twice'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Void expense'),
        ),
      ],
    );
  }
}
