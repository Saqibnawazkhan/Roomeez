import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${s.activeMembers.length} members',
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
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    onTap: () => widget.onOpenTab(GroupTab.members),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1_outlined, color: context.colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pending.length == 1
                                ? '${pending.first.name} wants to join'
                                : '${pending.length} people want to join',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(onPressed: () => widget.onOpenTab(GroupTab.members), child: const Text('Review')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _TotalCard(summary: summary),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Group fund left',
                          icon: Icons.savings_outlined,
                          color: context.appColors.fund,
                          value: fund.hasFund
                              ? AmountText(fund.remainingPaisa)
                              : Text('None', style: TextStyle(color: context.appColors.muted)),
                          onTap: () => context.push(Routes.groupSettings(s.group.id)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Your balance',
                          icon: Icons.account_balance_wallet_outlined,
                          color: context.colors.primary,
                          value: AmountText(myNet, signed: true, colorize: true),
                          onTap: () => widget.onOpenTab(GroupTab.members),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No expenses yet')
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
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final onPrimary = context.colors.onPrimary;
    final soft = onPrimary.withValues(alpha: 0.8);
    return Card(
      color: context.colors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total spent', style: context.text.labelLarge?.copyWith(color: soft)),
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
              '${summary.expenseCount} ${summary.expenseCount == 1 ? 'expense' : 'expenses'}',
              style: context.text.bodySmall?.copyWith(color: soft),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Widget value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: context.appColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
