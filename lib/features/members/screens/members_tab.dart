import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/phone.dart';
import '../../../core/neu/neu.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/group_snapshot.dart';
import '../../../data/models/models.dart';
import '../../../data/services/balance_calculator.dart';
import '../../../data/services/permission_policy.dart';
import '../../groups/group_providers.dart';

class MembersTab extends ConsumerWidget {
  const MembersTab({super.key, required this.snapshot});

  final GroupSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final pending = ref.watch(pendingJoinRequestsProvider(s.group.id)).value ?? const <JoinRequest>[];
    final summary = BalanceCalculator.summarize(
      members: s.members,
      expenses: s.expenses,
      contributions: s.contributions,
    );
    final canAdd = PermissionPolicy.canAddMember(s.me);

    return Scaffold(
      appBar: NeuHeader(
        title: 'Members',
        caption: '${s.activeMembers.length} active',
        showBack: false,
        trailing: [
          if (canAdd)
            NeuIconButton(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: 'Add member',
              color: NeuPalette.of(context).accent,
              onPressed: () => context.push(Routes.addMember(s.group.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          if (pending.isNotEmpty) ...[
            SectionHeader('Join requests (${pending.length})', padding: const EdgeInsets.fromLTRB(6, 10, 6, 12)),
            for (final request in pending) ...[
              _JoinRequestCard(request: request, snapshot: s),
              const SizedBox(height: 16),
            ],
          ],
          SectionHeader('Active members (${s.activeMembers.length})'),
          for (final m in s.activeMembers) _MemberTile(member: m, snapshot: s, balance: summary.balanceOf(m.userId)),

          if (s.formerMembers.isNotEmpty) ...[
            SectionHeader('Former members (${s.formerMembers.length})'),
            for (final m in s.formerMembers) _MemberTile(member: m, snapshot: s, balance: summary.balanceOf(m.userId)),
          ],
        ],
      ),
    );
  }
}

class _JoinRequestCard extends ConsumerStatefulWidget {
  const _JoinRequestCard({required this.request, required this.snapshot});

  final JoinRequest request;
  final GroupSnapshot snapshot;

  @override
  ConsumerState<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends ConsumerState<_JoinRequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final r = widget.request;
    if (!approve) {
      final ok = await showConfirmDialog(
        context,
        title: 'Decline ${r.name}?',
        message: 'They won\'t be added to the group.',
        confirmLabel: 'Decline',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final repo = ref.read(groupRepositoryProvider);
    try {
      if (approve) {
        await repo.approveJoinRequest(actorUserId: widget.snapshot.viewerUserId, requestId: r.id);
      } else {
        await repo.declineJoinRequest(actorUserId: widget.snapshot.viewerUserId, requestId: r.id);
      }
      if (mounted) showAppSnack(context, approve ? '${r.name} joined the group' : 'Request declined');
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, describeError(error), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(name: r.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [?r.email, AppDates.relativeDay(r.requestedAt)].join('  ·  '),
                      style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Center(
              child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: NeuButton(label: 'Decline', primary: false, height: 46, onPressed: () => _decide(false)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: NeuButton(label: 'Approve', height: 46, onPressed: () => _decide(true)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.snapshot, required this.balance});

  final GroupMember member;
  final GroupSnapshot snapshot;
  final MemberBalance? balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = member;
    final isMe = m.userId == snapshot.viewerUserId;
    final period = m.isActive
        ? 'Since ${AppDates.day(m.startDate)}'
        : '${AppDates.short(m.startDate)} – ${AppDates.day(m.endDate ?? m.startDate)}  ·  ${m.status.label}';

    final palette = NeuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuPressable(
        onTap: () => _showDetails(context, ref),
        radius: 30,
        depth: 5,
        padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
        child: Row(
          children: [
            MemberAvatar(name: m.displayName, muted: !m.isActive, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${m.displayName} (you)' : m.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    m.isManager ? 'Manager · $period' : period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ],
              ),
            ),
            AmountText(
              balance?.netPaisa ?? 0,
              signed: true,
              colorize: true,
              roundToRupee: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _MemberSheet(member: member, snapshot: snapshot, balance: balance),
    );
  }
}

class _MemberSheet extends ConsumerStatefulWidget {
  const _MemberSheet({required this.member, required this.snapshot, required this.balance});

  final GroupMember member;
  final GroupSnapshot snapshot;
  final MemberBalance? balance;

  @override
  ConsumerState<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<_MemberSheet> {
  bool _busy = false;

  Future<void> _remove() async {
    final m = widget.member;
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${m.displayName}?',
      message: 'They\'ll lose access to this group. Their past expenses stay.',
      confirmLabel: 'Remove member',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(actorUserId: widget.snapshot.viewerUserId, groupId: widget.snapshot.group.id, memberId: m.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, '${m.displayName} removed');
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, describeError(error), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final s = widget.snapshot;
    final b = widget.balance;
    final canRemove = PermissionPolicy.canRemoveMember(actor: s.me, target: m);
    final expensesAdded = s.expenses.where((e) => e.createdByUserId == m.userId).length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(name: m.displayName, size: 56, muted: !m.isActive),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.displayName, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      if (m.email != null) Text(m.email!, style: TextStyle(color: context.appColors.muted)),
                      if (m.phone != null)
                        Text(PhoneNumber.format(m.phone!), style: TextStyle(color: context.appColors.muted)),
                      if (m.email == null && m.isActive)
                        Text('Offline member (no email)', style: TextStyle(color: context.appColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _row(context, 'Status', m.isManager ? 'Active · Group manager' : m.status.label),
                  _row(context, 'Member since', AppDates.day(m.startDate)),
                  if (m.endDate != null) _row(context, 'Until', AppDates.day(m.endDate!)),
                  if (m.addedByUserId != null && m.addedByUserId != m.userId)
                    _row(context, 'Added by', s.nameOf(m.addedByUserId)),
                  _row(context, 'Expenses added', '$expensesAdded'),
                ],
              ),
            ),
            if (b != null) ...[
              const SectionHeader('Balance (all time)'),
              AppCard(
                child: Column(
                  children: [
                    _amountRow(context, 'Contributions to fund', b.contributedPaisa),
                    _amountRow(context, 'Expenses paid personally', b.paidPersonallyPaisa),
                    _amountRow(context, 'Share of expenses', -b.sharePaisa),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Balance', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        AmountText(
                          b.netPaisa,
                          signed: true,
                          colorize: true,
                          roundToRupee: true,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (canRemove) ...[
              const SizedBox(height: 20),
              NeuButton(
                label: 'Remove member',
                icon: Icons.person_remove_outlined,
                primary: false,
                destructive: true,
                onPressed: _busy ? null : _remove,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: context.appColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _amountRow(BuildContext context, String label, int paisa) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: context.appColors.muted)),
          ),
          AmountText(
            paisa,
            signed: paisa < 0,
            roundToRupee: true,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
