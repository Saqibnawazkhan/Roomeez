import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';

/// One expense as a raised pill (like the player rows in the reference).
/// Tapping opens the details; there are deliberately no swipe actions.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, required this.snapshot, this.showDate = false});

  final Expense expense;
  final GroupSnapshot snapshot;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final palette = NeuPalette.of(context);
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuPressable(
        onTap: () => context.push(Routes.expense(e.groupId, e.id)),
        radius: 30,
        depth: 5,
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        child: Row(
          children: [
            CategoryIcon(e.category, size: 46, muted: e.isVoided),
            const SizedBox(width: 14),
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: e.isVoided ? TextDecoration.lineThrough : null,
                            color: e.isVoided ? palette.muted : palette.text,
                          ),
                        ),
                      ),
                      if (e.isVoided) ...[const SizedBox(width: 6), Pill('Voided', color: palette.muted)],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AmountText(
              e.totalPaisa,
              strikethrough: e.isVoided,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: e.isVoided ? palette.muted : palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
