import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/period_selector.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';
import '../../contributions/widgets/fund_card.dart';
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
    final mine = allTime.balanceOf(s.viewerUserId);
    final recent = s.expenses.where((e) => range == null || range.contains(e.date)).take(5).toList();
    final pending = ref.watch(pendingJoinRequestsProvider(s.group.id)).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Code ${s.group.code}  ·  ${s.activeMembers.length} members',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Group settings',
            onPressed: () => context.push(Routes.groupSettings(s.group.id)),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: PermissionPolicy.canAddExpense(s.me)
          ? FloatingActionButton.extended(
              heroTag: 'dashboard-add',
              onPressed: () => context.push(Routes.addExpense(s.group.id)),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const SizedBox(height: 4),
          PeriodSelector(value: _period, onChanged: (p) => setState(() => _period = p)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending.isNotEmpty) ...[
                  InfoBanner(
                    icon: Icons.person_add_alt_1_outlined,
                    message: pending.length == 1
                        ? '${pending.first.name} wants to join this group.'
                        : '${pending.length} people want to join this group.',
                    action: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => widget.onOpenTab(GroupTab.members),
                      child: const Text('Review requests'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _TotalCard(summary: summary, period: _period),
                const SizedBox(height: 12),
                FundCard(snapshot: s),
                const SizedBox(height: 12),
                if (mine != null) _MyBalanceCard(net: mine.netPaisa, onTap: () => widget.onOpenTab(GroupTab.members)),
                if (summary.byCategory.isNotEmpty) ...[
                  const SectionHeader('By category'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (final entry in summary.byCategory.take(4))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                CategoryIcon(entry.key, size: 32),
                                const SizedBox(width: 12),
                                Expanded(child: Text(entry.key.label)),
                                AmountText(entry.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                SectionHeader(
                  'Recent expenses',
                  trailing: TextButton(
                    onPressed: () => widget.onOpenTab(GroupTab.expenses),
                    child: const Text('See all'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: recent.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses in this period',
                      message: 'Tap "Add expense" to record the first one.',
                    )
                  : Column(
                      children: [
                        for (final (i, e) in recent.indexed) ...[
                          if (i > 0) const Divider(indent: 70),
                          ExpenseTile(expense: e, snapshot: s, showDate: true),
                        ],
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(
              'Members',
              trailing: TextButton(onPressed: () => widget.onOpenTab(GroupTab.members), child: const Text('View all')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              onTap: () => widget.onOpenTab(GroupTab.members),
              child: Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  for (final m in s.activeMembers)
                    SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          MemberAvatar(name: m.displayName, size: 44),
                          const SizedBox(height: 4),
                          Text(
                            m.userId == s.viewerUserId ? 'You' : m.displayName.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary, required this.period});

  final FinancialSummary summary;
  final PeriodFilter period;

  @override
  Widget build(BuildContext context) {
    final onPrimary = context.colors.onPrimary;
    final soft = onPrimary.withValues(alpha: 0.78);
    return Card(
      color: context.colors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total expenses', style: context.text.labelLarge?.copyWith(color: soft)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                summary.totalExpensesPaisa,
                style: context.text.displaySmall?.copyWith(color: onPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${summary.expenseCount} ${summary.expenseCount == 1 ? 'expense' : 'expenses'}  ·  ${period.describe()}',
              style: context.text.bodySmall?.copyWith(color: soft),
            ),
            const SizedBox(height: 14),
            Divider(color: onPrimary.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _split(context, 'Paid personally', summary.paidPersonallyPaisa)),
                Expanded(child: _split(context, 'Paid from group fund', summary.paidFromFundPaisa)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _split(BuildContext context, String label, int paisa) {
    final onPrimary = context.colors.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelSmall?.copyWith(color: onPrimary.withValues(alpha: 0.78))),
        const SizedBox(height: 2),
        AmountText(
          paisa,
          style: context.text.titleSmall?.copyWith(color: onPrimary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MyBalanceCard extends StatelessWidget {
  const _MyBalanceCard({required this.net, required this.onTap});

  final int net;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (net > 0) {
      message = 'You\'ve put in ${Money.format(net)} more than your share.';
    } else if (net < 0) {
      message = 'Your share is ${Money.format(-net)} more than what you\'ve put in.';
    } else {
      message = 'You\'re all square with the group.';
    }
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your balance (all time)',
                  style: context.text.labelLarge?.copyWith(color: context.appColors.muted),
                ),
                const SizedBox(height: 2),
                AmountText(
                  net,
                  signed: true,
                  colorize: true,
                  style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(message, style: context.text.bodySmall?.copyWith(color: context.appColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
