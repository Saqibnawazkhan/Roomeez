import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/services/balance_calculator.dart';
import '../../groups/group_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NeuPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final groups = ref.watch(myGroupsProvider);
    final pending = (ref.watch(myJoinRequestsProvider).value ?? const <JoinRequest>[])
        .where((r) => r.isPending)
        .toList();
    final firstName = (user?.name ?? '').split(' ').first;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            // Header: profile and today's date (like the reference).
            Row(
              children: [
                NeuIconButton(
                  icon: Icons.person_rounded,
                  tooltip: 'Profile',
                  onPressed: () => context.push(Routes.profile),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE').format(now),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: palette.text, height: 1.1),
                      ),
                      Text(
                        DateFormat('MMM d').format(now).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Keeps the date centered.
                const SizedBox(width: 46),
              ],
            ),
            const SizedBox(height: 30),
            NeuPressable(
              onTap: () => context.push(Routes.profile),
              radius: 28,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  MemberAvatar(name: user?.name ?? '?', size: 84),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $firstName!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: palette.text, height: 1.2),
                        ),
                        if (user?.email != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user!.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Create group',
                      subtitle: 'Flat or room',
                      icon: Icons.add_home_work_rounded,
                      onTap: () => context.push(Routes.createGroup),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _ActionCard(
                      title: 'Join group',
                      subtitle: 'With a code',
                      icon: Icons.group_add_rounded,
                      onTap: () => context.push(Routes.joinGroup),
                    ),
                  ),
                ],
              ),
            ),
            if (pending.isNotEmpty) ...[
              const NeuSectionLabel('Waiting for approval'),
              for (final request in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NeuPressable(
                    onTap: () => context.push(Routes.joinStatus(request.id)),
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
                    child: Row(
                      children: [
                        NeuBox(
                          style: NeuStyle.inset,
                          circle: true,
                          width: 44,
                          height: 44,
                          child: Icon(Icons.hourglass_top_rounded, color: palette.accent, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(request.groupName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                'Requested ${AppDates.relativeDay(request.requestedAt).toLowerCase()}',
                                style: TextStyle(fontSize: 12, color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const NeuSectionLabel('Your groups'),
            groups.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
              error: (error, _) => ErrorView(error: error),
              data: (groups) => groups.isEmpty
                  ? const EmptyState(
                      icon: Icons.groups_2_outlined,
                      title: 'No groups yet',
                      message: 'Create one or join with a code.',
                    )
                  : Column(children: [for (final group in groups) _GroupCard(group: group)]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Like the Wi-Fi / Bluetooth cards in the reference.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuPressable(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.text, fontSize: 14.5),
          ),
          Row(
            children: [
              Expanded(
                child: Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 12)),
              ),
              NeuBox(
                style: NeuStyle.inset,
                circle: true,
                width: 32,
                height: 32,
                child: Icon(icon, size: 16, color: palette.accent),
              ),
            ],
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
    final palette = NeuPalette.of(context);
    final snapshot = ref.watch(groupSnapshotProvider(group.id)).value;
    final month = const PeriodFilter.thisMonth().resolve();
    final spent = snapshot == null
        ? null
        : BalanceCalculator.summarize(
            members: snapshot.members,
            expenses: snapshot.expenses,
            contributions: snapshot.contributions,
            range: month,
          ).totalExpensesPaisa;
    final myNet = snapshot == null
        ? null
        : BalanceCalculator.summarize(
            members: snapshot.members,
            expenses: snapshot.expenses,
            contributions: snapshot.contributions,
          ).balanceOf(snapshot.viewerUserId)?.netPaisa;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeuPressable(
        onTap: () => context.push(Routes.group(group.id)),
        radius: 28,
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                NeuBox(
                  circle: true,
                  width: 52,
                  height: 52,
                  depth: 4,
                  child: Icon(Icons.home_work_rounded, color: palette.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text),
                      ),
                      Text(
                        snapshot == null ? ' ' : '${snapshot.activeMembers.length} members'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot?.me?.isManager ?? false) Pill('Manager', color: palette.accent),
              ],
            ),
            if (spent != null) ...[
              const SizedBox(height: 16),
              NeuBox(
                style: NeuStyle.inset,
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: LabeledValue(label: 'This month', value: AmountText(spent)),
                    ),
                    Expanded(
                      child: LabeledValue(
                        label: 'Your balance',
                        value: AmountText(myNet ?? 0, signed: true, colorize: true, roundToRupee: true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
