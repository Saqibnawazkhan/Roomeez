import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/common.dart';
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
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) => _select(GroupTab.values[index]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Expenses',
            ),
            const NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.group_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.group),
              ),
              label: 'Members',
            ),
          ],
        ),
      ),
    );
  }
}
