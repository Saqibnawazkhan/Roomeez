import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../groups/group_providers.dart';
import '../widgets/fund_card.dart';

/// The shared money pool: what's left, adding money, and every contribution.
class GroupFundScreen extends ConsumerWidget {
  const GroupFundScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(groupSnapshotProvider(groupId));
    return Scaffold(
      appBar: NeuHeader(title: 'Group fund', caption: 'Shared money'),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            FundCard(snapshot: s),
            const NeuSectionLabel('History'),
            if (s.contributions.isEmpty)
              const EmptyState(
                icon: Icons.savings_outlined,
                title: 'No money added yet',
                message: 'Money added to the fund shows here.',
              )
            else
              for (final c in s.contributions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NeuBox(
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
                    child: Row(
                      children: [
                        MemberAvatar(name: s.nameOf(c.memberUserId), size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nameOf(c.memberUserId), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${c.type.label} · ${AppDates.day(c.date)}${c.note == null ? '' : ' · ${c.note}'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: NeuPalette.of(context).muted),
                              ),
                            ],
                          ),
                        ),
                        AmountText(
                          c.amountPaisa,
                          style: TextStyle(fontWeight: FontWeight.w700, color: context.appColors.fund),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
