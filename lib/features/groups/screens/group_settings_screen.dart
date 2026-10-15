import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/services/permission_policy.dart';
import '../../contributions/widgets/fund_card.dart';
import '../group_providers.dart';
import '../widgets/group_code_card.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _busy = false;

  Future<void> _regenerate(GroupSnapshot s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Generate a new code?',
      message: 'The current code ${s.group.code} will stop working. Existing members are not affected.',
      confirmLabel: 'Generate',
    );
    if (!ok || !mounted) return;
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .regenerateCode(actorUserId: s.viewerUserId, groupId: s.group.id);
      if (mounted) showAppSnack(context, 'New code: ${group.code}');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  Future<void> _leave(GroupSnapshot s) async {
    final me = s.me;
    if (me == null) return;
    final others = s.activeMembers.where((m) => m.userId != s.viewerUserId).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final successor = me.isManager && others.isNotEmpty ? others.first.displayName : null;
    final ok = await showConfirmDialog(
      context,
      title: 'Leave "${s.group.name}"?',
      message: [
        'You\'ll lose access. Your past expenses stay in the group.',
        if (successor != null) '$successor will become the manager.',
      ].join('\n\n'),
      confirmLabel: 'Leave group',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(groupRepositoryProvider)
          .leaveGroup(actorUserId: s.viewerUserId, groupId: s.group.id);
      if (!mounted) return;
      context.go(Routes.home);
      showAppSnack(
        context,
        result.newManagerName == null
            ? 'You left ${s.group.name}'
            : 'You left ${s.group.name}. ${result.newManagerName} is now the manager.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, describeError(error), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(groupSnapshotProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => _busy ? const LoadingView() : ErrorView(error: error),
        data: (s) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.group.name, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (s.group.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.group.description!,
                        style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Manager: ${s.manager?.displayName ?? 'None'}',
                      style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Invite people'),
              GroupCodeCard(
                group: s.group,
                trailing: PermissionPolicy.canRegenerateCode(s.me)
                    ? TextButton.icon(
                        onPressed: () => _regenerate(s),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Generate a new code'),
                      )
                    : null,
              ),
              const SectionHeader('Group fund'),
              FundCard(snapshot: s),
              if (s.contributions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final (i, c) in s.contributions.indexed) ...[
                        if (i > 0) const Divider(indent: 16),
                        ListTile(
                          leading: MemberAvatar(name: s.nameOf(c.memberUserId), size: 36),
                          title: Text(s.nameOf(c.memberUserId), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${c.type.label}  ·  ${AppDates.day(c.date)}${c.note == null ? '' : '\n${c.note}'}',
                          ),
                          isThreeLine: c.note != null,
                          trailing: AmountText(
                            c.amountPaisa,
                            style: TextStyle(fontWeight: FontWeight.w700, color: context.appColors.fund),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error,
                  side: BorderSide(color: context.colors.error.withValues(alpha: 0.5)),
                ),
                onPressed: _busy ? null : () => _leave(s),
                icon: const Icon(Icons.logout),
                label: const Text('Leave group'),
              ),
            ],
          );
        },
      ),
    );
  }
}
