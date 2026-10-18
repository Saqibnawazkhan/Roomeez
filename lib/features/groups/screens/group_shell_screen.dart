import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../expenses/screens/expenses_tab.dart';
import '../../members/screens/members_tab.dart';
import '../../reports/screens/reports_tab.dart';
import '../group_providers.dart';
import 'dashboard_tab.dart';

/// A group's home: Dashboard, Expenses, Reports and Members tabs.
class GroupShellScreen extends ConsumerStatefulWidget {
  const GroupShellScreen({super.key, required this.groupId, this.initialTab = GroupTab.dashboard});

  final String groupId;
  final GroupTab initialTab;

  @override
  ConsumerState<GroupShellScreen> createState() => _GroupShellScreenState();
}

class _GroupShellScreenState extends ConsumerState<GroupShellScreen> {
  late GroupTab _tab = widget.initialTab;

  void _select(GroupTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(groupSnapshotProvider(widget.groupId));
    final pendingCount = ref.watch(pendingJoinRequestsProvider(widget.groupId)).value?.length ?? 0;

    return snapshot.when(
      loading: () => Scaffold(
        appBar: NeuHeader(title: ''),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: NeuHeader(title: ''),
        body: ErrorView(
          error: error,
          action: FilledButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
        ),
      ),
      data: (data) => Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            DashboardTab(snapshot: data, onOpenTab: _select),
            ExpensesTab(snapshot: data),
            ReportsTab(snapshot: data),
            MembersTab(snapshot: data),
          ],
        ),
        bottomNavigationBar: NeuBottomNav(
          index: _tab.index,
          onTap: (index) => _select(GroupTab.values[index]),
          hues: const [NeuHues.teal, NeuHues.coral, NeuHues.amber, NeuHues.indigo],
          items: [
            (Icons.space_dashboard_rounded, 'Dashboard', 0),
            (Icons.receipt_long_rounded, 'Expenses', 0),
            (Icons.insert_chart_rounded, 'Reports', 0),
            (Icons.group_rounded, 'Members', pendingCount),
          ],
        ),
      ),
    );
  }
}
