import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';
import '../../expenses/widgets/expense_tile.dart';
import '../group_providers.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key, required this.snapshot, required this.onOpenTab});

  final GroupSnapshot snapshot;
  final ValueChanged<GroupTab> onOpenTab;

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  PeriodFilter _period = const PeriodFilter.thisMonth();

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final palette = NeuPalette.of(context);
    final range = _period.resolve();
    final summary = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
      range: range,
    );
    final allTime = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
    );
    final fund = BalanceCalculator.fundStatus(expenses: s.expenses, contributions: s.contributions);
    final myNet = allTime.balanceOf(s.viewerUserId)?.netPaisa ?? 0;
    final recent = s.expenses.where((e) => range == null || range.contains(e.date)).take(5).toList();
    final pending = ref.watch(pendingJoinRequestsProvider(s.group.id)).value ?? const [];
    final canAdd = PermissionPolicy.canAddExpense(s.me);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: NeuHeader(
        title: s.group.name,
        caption: '${s.activeMembers.length} members',
        trailing: [
          NeuIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Group settings',
            onPressed: () => context.push(Routes.groupSettings(s.group.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending.isNotEmpty) ...[
                  NeuPressable(
                    onTap: () => widget.onOpenTab(GroupTab.members),
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: palette.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pending.length == 1
                                ? '${pending.first.name} wants to join'
                                : '${pending.length} people want to join',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          'Review',
                          style: TextStyle(color: palette.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                _TotalCard(summary: summary, onAdd: canAdd ? () => context.push(Routes.addExpense(s.group.id)) : null),
                const NeuSectionLabel('Group fund'),
                if (fund.hasFund)
                  GestureDetector(
                    onTap: () => context.push(Routes.groupSettings(s.group.id)),
                    child: Column(
                      children: [
                        NeuProgress(
                          value: fund.contributedPaisa == 0 ? 0 : fund.remainingPaisa / fund.contributedPaisa,
                          startLabel: fund.contributedPaisa == 0
                              ? '0%'
                              : '${(fund.remainingPaisa * 100 / fund.contributedPaisa).round().clamp(0, 100)}%',
                          endLabel: '100%',
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${Money.format(fund.remainingPaisa, roundToRupee: true)} left',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: palette.text, fontSize: 13.5),
                                ),
                              ),
                              Text(
                                'of ${Money.format(fund.contributedPaisa, roundToRupee: true)}',
                                style: TextStyle(color: palette.muted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  NeuPressable(
                    onTap: () => context.push(Routes.addContribution(s.group.id)),
                    radius: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.savings_outlined, color: palette.accent),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('No group fund yet')),
                        Text(
                          'Add money',
                          style: TextStyle(color: palette.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 26),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BalanceCard(
                          name: me?.name ?? s.nameOf(s.viewerUserId),
                          net: myNet,
                          onTap: () => widget.onOpenTab(GroupTab.members),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _SmallCard(
                                title: 'Members',
                                value: '${s.activeMembers.length}',
                                icon: Icons.group_rounded,
                                onTap: () => widget.onOpenTab(GroupTab.members),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: _SmallCard(
                                title: 'Group code',
                                value: s.group.code,
                                icon: Icons.copy_rounded,
                                onTap: () async {
                                  await Clipboard.setData(ClipboardData(text: s.group.code));
                                  if (context.mounted) showAppSnack(context, 'Code copied');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                NeuSectionLabel(
                  'Recent expenses',
                  trailing: GestureDetector(
                    onTap: () => widget.onOpenTab(GroupTab.expenses),
                    child: Text(
                      'See all',
                      style: TextStyle(color: palette.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (recent.isEmpty)
                  const EmptyState(icon: Icons.receipt_long_outlined, title: 'No expenses yet')
                else
                  for (final e in recent) ExpenseTile(expense: e, snapshot: s, showDate: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Total spent" with a round accent button to add an expense.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary, required this.onAdd});

  final FinancialSummary summary;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuBox(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL SPENT',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: palette.muted),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    summary.totalExpensesPaisa,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: palette.text, height: 1.1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.expenseCount} ${summary.expenseCount == 1 ? 'expense' : 'expenses'}',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (onAdd != null)
            Tooltip(
              message: 'Add expense',
              child: Semantics(
                button: true,
                label: 'Add expense',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onAdd,
                  child: NeuBox(
                    circle: true,
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(7),
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.accentGradient),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Like the profile card in the reference: an avatar ring, a greeting and
/// the viewer's balance.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.name, required this.net, required this.onTap});

  final String name;
  final int net;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuPressable(
      onTap: onTap,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MemberAvatar(name: name, size: 66),
          const SizedBox(height: 12),
          Text('Your balance', style: TextStyle(color: palette.muted, fontSize: 12.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(
              net,
              signed: true,
              colorize: true,
              roundToRupee: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Like the Wi-Fi / Bluetooth cards in the reference.
class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.title, required this.value, required this.icon, required this.onTap});

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuPressable(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.text, fontSize: 14),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
              NeuBox(
                style: NeuStyle.inset,
                circle: true,
                width: 30,
                height: 30,
                child: Icon(icon, size: 15, color: palette.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
