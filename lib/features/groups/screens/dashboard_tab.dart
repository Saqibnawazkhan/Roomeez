import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';
import '../../expenses/widgets/expense_tile.dart';
import '../group_providers.dart';
import '../widgets/group_code_card.dart';

/// The group's front page, kept simple: this month's spending, the three
/// things people do most, their balance in plain words, and recent expenses.
/// Each card leads to exactly one place.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key, required this.snapshot, required this.onOpenTab});

  final GroupSnapshot snapshot;
  final ValueChanged<GroupTab> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final palette = NeuPalette.of(context);
    final month = const PeriodFilter.thisMonth().resolve();
    final thisMonth = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
      range: month,
    );
    final allTime = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
    );
    final fund = BalanceCalculator.fundStatus(expenses: s.expenses, contributions: s.contributions);
    final myNet = allTime.balanceOf(s.viewerUserId)?.netPaisa ?? 0;
    final recent = s.expenses.take(5).toList();
    final pending = ref.watch(pendingJoinRequestsProvider(s.group.id)).value ?? const [];

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (pending.isNotEmpty) ...[
            _LinkCard(
              icon: Icons.person_add_alt_1_rounded,
              hue: NeuHues.indigo,
              title: pending.length == 1
                  ? '${pending.first.name} wants to join'
                  : '${pending.length} people want to join',
              subtitle: 'Tap to approve or decline',
              onTap: () => onOpenTab(GroupTab.members),
            ),
            const SizedBox(height: 20),
          ],
          _MonthCard(summary: thisMonth),
          const SizedBox(height: 22),
          Row(
            children: [
              if (PermissionPolicy.canAddExpense(s.me)) ...[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_rounded,
                    label: 'Add expense',
                    hue: NeuHues.coral,
                    onTap: () => context.push(Routes.addExpense(s.group.id)),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              if (PermissionPolicy.canAddContribution(s.me)) ...[
                Expanded(
                  child: _QuickAction(
                    icon: Icons.savings_rounded,
                    label: 'Add money',
                    hue: NeuHues.violet,
                    onTap: () => context.push(Routes.addContribution(s.group.id)),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: _QuickAction(
                  icon: Icons.share_rounded,
                  label: 'Invite',
                  hue: NeuHues.amber,
                  onTap: () => _showInvite(context, s),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _BalanceCard(net: myNet, onTap: () => onOpenTab(GroupTab.members)),
          if (fund.hasFund) ...[
            const SizedBox(height: 18),
            _FundCard(fund: fund, onTap: () => context.push(Routes.groupFund(s.group.id))),
          ],
          NeuSectionLabel(
            'Recent expenses',
            trailing: recent.isEmpty
                ? null
                : GestureDetector(
                    onTap: () {
                      Haptics.tap();
                      onOpenTab(GroupTab.expenses);
                    },
                    child: Text(
                      'See all',
                      style: TextStyle(color: palette.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          if (recent.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No expenses yet',
              message: 'Tap "Add expense" to add the first one.',
            )
          else
            for (final e in recent) ExpenseTile(expense: e, snapshot: s, showDate: true),
        ],
      ),
    );
  }

  void _showInvite(BuildContext context, GroupSnapshot s) {
    final palette = NeuPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite people',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: palette.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Share this code. They open Roomeez, tap "Join group" and enter it.',
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
            const SizedBox(height: 18),
            GroupCodeCard(group: s.group),
          ],
        ),
      ),
    );
  }
}

/// This month's spending, in the group's teal.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final count = summary.expenseCount;
    final soft = Colors.white.withValues(alpha: 0.85);
    return NeuBox(
      radius: 28,
      gradient: NeuHues.gradient(NeuHues.teal),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPENT THIS MONTH',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: soft),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
              summary.totalExpensesPaisa,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.white, height: 1.1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 0
                ? 'Nothing added in ${DateFormat('MMMM').format(DateTime.now())} yet'
                : '$count ${count == 1 ? 'expense' : 'expenses'} in ${DateFormat('MMMM').format(DateTime.now())}',
            style: TextStyle(color: soft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// A labeled round button for one of the main actions.
class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.hue, required this.onTap});

  final IconData icon;
  final String label;
  final Color hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuPressable(
      onTap: onTap,
      radius: 24,
      semanticLabel: label,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
      child: Column(
        children: [
          NeuIconDisc(icon: icon, color: hue, size: 48),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: NeuPalette.of(context).text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card that leads somewhere: icon, title, subtitle and a chevron.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.bottom,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuPressable(
      onTap: onTap,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              NeuIconDisc(icon: icon, color: hue, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor ?? palette.text),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

/// The viewer's balance in plain words; leads to everyone's balances.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.net, required this.onTap});

  final int net;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final amount = Money.format(net.abs(), roundToRupee: true);
    final settled = (net.abs() + 50) ~/ 100 == 0;
    final (icon, hue, title) = settled
        ? (Icons.check_rounded, NeuHues.teal, "You're all settled")
        : net > 0
        ? (Icons.south_west_rounded, colors.positive, 'You get back $amount')
        : (Icons.north_east_rounded, colors.negative, 'You owe $amount');
    return _LinkCard(
      icon: icon,
      hue: hue,
      title: title,
      titleColor: settled ? null : hue,
      subtitle: "See everyone's balance",
      onTap: onTap,
    );
  }
}

/// What's left in the group fund; leads to the fund details in settings.
class _FundCard extends StatelessWidget {
  const _FundCard({required this.fund, required this.onTap});

  final FundStatus fund;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = fund.contributedPaisa == 0 ? 0.0 : (fund.remainingPaisa / fund.contributedPaisa).clamp(0.0, 1.0);
    return _LinkCard(
      icon: Icons.savings_rounded,
      hue: NeuHues.violet,
      title: 'Group fund',
      subtitle:
          '${Money.format(fund.remainingPaisa, roundToRupee: true)} left of '
          '${Money.format(fund.contributedPaisa, roundToRupee: true)}',
      onTap: onTap,
      bottom: NeuBox(
        style: NeuStyle.inset,
        radius: 7,
        height: 14,
        padding: const EdgeInsets.all(3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: left == 0 ? 0.02 : left,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: NeuHues.gradient(NeuHues.violet),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
