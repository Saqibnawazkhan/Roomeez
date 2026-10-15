import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/services/balance_calculator.dart';
import '../../groups/group_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final groups = ref.watch(myGroupsProvider);
    final pending = (ref.watch(myJoinRequestsProvider).value ?? const <JoinRequest>[])
        .where((r) => r.isPending)
        .toList();
    final firstName = (user?.name ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roomeez'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push(Routes.profile),
            icon: MemberAvatar(name: user?.name ?? '?', size: 34),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('Hi, $firstName', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_home_work_outlined,
                    title: 'Create group',
                    subtitle: 'For your flat or room',
                    primary: true,
                    onTap: () => context.push(Routes.createGroup),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.group_add_outlined,
                    title: 'Join group',
                    subtitle: 'With a group code',
                    onTap: () => context.push(Routes.joinGroup),
                  ),
                ),
              ],
            ),
            if (pending.isNotEmpty) ...[
              const SectionHeader('Waiting for approval'),
              for (final request in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => context.push(Routes.joinStatus(request.id)),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: context.colors.tertiary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.groupName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                'Requested ${AppDates.relativeDay(request.requestedAt).toLowerCase()}',
                                style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
            ],
            const SectionHeader('Your groups'),
            groups.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
              error: (error, _) => ErrorView(error: error),
              data: (groups) => groups.isEmpty
                  ? AppCard(
                      child: EmptyState(
                        icon: Icons.groups_2_outlined,
                        title: 'No groups yet',
                        message: 'Create one or join with a code.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final group in groups)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GroupCard(group: group),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? context.colors.onPrimary : context.colors.onSurface;
    return AppCard(
      color: primary ? context.colors.primary : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary ? fg : context.colors.primary, size: 28),
          const SizedBox(height: 18),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(groupSnapshotProvider(group.id)).value;
    final month = const PeriodFilter.thisMonth().resolve();
    final summary = snapshot == null
        ? null
        : BalanceCalculator.summarize(
            members: snapshot.members,
            expenses: snapshot.expenses,
            contributions: snapshot.contributions,
            range: month,
          );
    final allTime = snapshot == null
        ? null
        : BalanceCalculator.summarize(
            members: snapshot.members,
            expenses: snapshot.expenses,
            contributions: snapshot.contributions,
          );
    final myNet = allTime?.balanceOf(snapshot!.viewerUserId)?.netPaisa;

    return AppCard(
      onTap: () => context.push(Routes.group(group.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.home_work_outlined, color: context.colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      snapshot == null ? 'Code ${group.code}' : '${snapshot.activeMembers.length} members',
                      style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                    ),
                  ],
                ),
              ),
              if (snapshot?.me?.isManager ?? false) const Pill('Manager'),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LabeledValue(label: 'This month', value: AmountText(summary.totalExpensesPaisa)),
                ),
                Expanded(
                  child: LabeledValue(
                    label: 'Your balance',
                    value: AmountText(myNet ?? 0, signed: true, colorize: true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
