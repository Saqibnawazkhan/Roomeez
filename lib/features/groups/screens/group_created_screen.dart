import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/common.dart';
import '../../../data/services/balance_calculator.dart';
import '../group_providers.dart';
import '../widgets/group_code_card.dart';

class GroupCreatedScreen extends ConsumerWidget {
  const GroupCreatedScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(groupSnapshotProvider(groupId));
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (data) {
          final fund = BalanceCalculator.fundStatus(expenses: data.expenses, contributions: data.contributions);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: context.colors.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded, size: 40, color: context.colors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"${data.group.name}" is ready',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Share the code with your flatmates so they can join. '
                'Members you added can sign up with their number to see the group.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
              ),
              const SizedBox(height: 20),
              GroupCodeCard(group: data.group),
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: LabeledValue(label: 'Members', value: Text('${data.activeMembers.length}')),
                    ),
                    Expanded(
                      child: LabeledValue(
                        label: 'Initial contributions',
                        value: Text(fund.contributedPaisa == 0 ? 'None' : Money.format(fund.contributedPaisa)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Open group dashboard', onPressed: () => context.go(Routes.group(groupId))),
      ),
    );
  }
}
