import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';

/// One expense in a list. Tapping opens the details. There are deliberately
/// no swipe actions on expense rows.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, required this.snapshot, this.showDate = false});

  final Expense expense;
  final GroupSnapshot snapshot;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final muted = context.appColors.muted;
    final addedBy = snapshot.nameOf(e.createdByUserId).split(' ').first;
    final String paid;
    if (e.paymentSource == PaymentSource.groupFund) {
      paid = 'Group fund';
    } else {
      final payer = snapshot.nameOf(e.paidByUserId).split(' ').first;
      paid = payer == addedBy ? payer : '$payer (added by $addedBy)';
    }
    final subtitle = [
      if (showDate) AppDates.relativeDay(e.date),
      paid,
      if (e.isItemized) '${e.items.length} ${e.items.length == 1 ? 'item' : 'items'}',
    ].join(' · ');

    return InkWell(
      onTap: () => context.push(Routes.expense(e.groupId, e.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CategoryIcon(e.category, muted: e.isVoided),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: e.isVoided ? TextDecoration.lineThrough : null,
                            color: e.isVoided ? muted : null,
                          ),
                        ),
                      ),
                      if (e.isVoided) ...[const SizedBox(width: 6), Pill('Voided', color: muted)],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AmountText(
              e.totalPaisa,
              strikethrough: e.isVoided,
              style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: e.isVoided ? muted : null),
            ),
          ],
        ),
      ),
    );
  }
}
