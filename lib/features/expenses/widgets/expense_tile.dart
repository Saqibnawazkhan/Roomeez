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
    final payer = e.paymentSource == PaymentSource.groupFund ? 'Group fund' : snapshot.nameOf(e.paidByUserId);
    final addedBy = snapshot.nameOf(e.createdByUserId);
    final meta = <String>[
      if (showDate) AppDates.relativeDay(e.date),
      e.category.label,
      if (e.isItemized) '${e.items.length} ${e.items.length == 1 ? 'item' : 'items'}',
    ].join('  ·  ');

    return InkWell(
      onTap: () => context.push(Routes.expense(e.groupId, e.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontWeight: FontWeight.w700,
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
                    payer == addedBy ? 'Added and paid by $addedBy' : 'Added by $addedBy  ·  Paid by $payer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  e.totalPaisa,
                  strikethrough: e.isVoided,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: e.isVoided ? muted : null,
                  ),
                ),
                const SizedBox(height: 4),
                _SourceTag(source: e.paymentSource),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final PaymentSource source;

  @override
  Widget build(BuildContext context) {
    final fund = source == PaymentSource.groupFund;
    return Pill(
      fund ? 'Group fund' : 'Personal',
      color: fund ? context.appColors.fund : context.appColors.muted,
      icon: fund ? Icons.savings_outlined : Icons.person_outline,
    );
  }
}
