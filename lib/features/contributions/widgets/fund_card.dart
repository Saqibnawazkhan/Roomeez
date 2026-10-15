import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
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
    final colors = context.appColors;
    final canAdd = PermissionPolicy.canAddContribution(snapshot.me);
    final addButton = canAdd
        ? TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: colors.onFundContainer, visualDensity: VisualDensity.compact),
            onPressed: () => context.push(Routes.addContribution(snapshot.group.id)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add money'),
          )
        : null;

    return Card(
      color: colors.fundContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!fund.hasFund) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'No money added yet.',
                  style: context.text.bodySmall?.copyWith(color: colors.onFundContainer),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _figure(context, 'Added', fund.contributedPaisa)),
                  Expanded(child: _figure(context, 'Spent', fund.spentPaisa)),
                  Expanded(child: _figure(context, 'Left', fund.remainingPaisa, emphasize: true)),
                ],
              ),
            ],
            if (addButton != null) ...[const SizedBox(height: 4), addButton] else const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _figure(BuildContext context, String label, int paisa, {bool emphasize = false}) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelSmall?.copyWith(color: colors.onFundContainer.withValues(alpha: 0.8))),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AmountText(
            paisa,
            style: context.text.titleSmall?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: paisa < 0 ? colors.negative : colors.onFundContainer,
            ),
          ),
        ),
      ],
    );
  }
}
