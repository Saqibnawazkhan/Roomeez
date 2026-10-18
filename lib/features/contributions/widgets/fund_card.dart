import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';

/// The group fund, styled differently from expenses on purpose:
/// contributions are money put in, not money spent.
class FundCard extends StatelessWidget {
  const FundCard({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fund = BalanceCalculator.fundStatus(expenses: snapshot.expenses, contributions: snapshot.contributions);
    final canAdd = PermissionPolicy.canAddContribution(snapshot.me);
    final palette = NeuPalette.of(context);
    return NeuBox(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!fund.hasFund)
            Text('No money added yet.', style: TextStyle(color: palette.muted))
          else ...[
            NeuProgress(
              value: fund.contributedPaisa == 0 ? 0 : fund.remainingPaisa / fund.contributedPaisa,
              startLabel: fund.contributedPaisa == 0
                  ? '0%'
                  : '${(fund.remainingPaisa * 100 / fund.contributedPaisa).round().clamp(0, 100)}%',
              endLabel: '100%',
              hue: NeuHues.violet,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _figure(context, 'Added', fund.contributedPaisa)),
                Expanded(child: _figure(context, 'Spent', fund.spentPaisa)),
                Expanded(child: _figure(context, 'Left', fund.remainingPaisa, emphasize: true)),
              ],
            ),
          ],
          if (canAdd) ...[
            const SizedBox(height: 18),
            NeuButton(
              label: 'Add money',
              icon: Icons.add_rounded,
              primary: false,
              height: 48,
              onPressed: () => context.push(Routes.addContribution(snapshot.group.id)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _figure(BuildContext context, String label, int paisa, {bool emphasize = false}) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 1.5, color: colors.muted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AmountText(
            paisa,
            style: context.text.titleSmall?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: paisa < 0
                  ? colors.negative
                  : emphasize
                  ? NeuHues.violet
                  : NeuPalette.of(context).text,
            ),
          ),
        ),
      ],
    );
  }
}
