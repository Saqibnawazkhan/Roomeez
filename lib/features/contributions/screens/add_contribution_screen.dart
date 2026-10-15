import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/common.dart';
import '../../groups/group_providers.dart';

/// Records money a member puts into the group fund.
class AddContributionScreen extends ConsumerStatefulWidget {
  const AddContributionScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddContributionScreen> createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends ConsumerState<AddContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _memberUserId;
  DateTime _date = today();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    final memberId = _memberUserId ?? userId;
    if (userId == null || memberId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .addContribution(
            actorUserId: userId,
            groupId: widget.groupId,
            memberUserId: memberId,
            amountPaisa: Money.tryParse(_amount.text)!,
            date: _date,
            note: _note.text,
          );
      if (!mounted) return;
      context.pop();
      showAppSnack(context, 'Contribution recorded in the group fund');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(groupSnapshotProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Add contribution')),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (s) {
          final selected = _memberUserId ?? s.viewerUserId;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const InfoBanner(
                  tone: BannerTone.fund,
                  message:
                      'Contributions go into the group fund that expenses can be paid from. '
                      'They are not expenses and are not counted in total expenses.',
                ),
                const SectionHeader('Who is contributing?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in s.activeMembers)
                      ChoiceChip(
                        avatar: MemberAvatar(name: m.displayName, size: 24),
                        label: Text(m.userId == s.viewerUserId ? 'You' : m.displayName),
                        selected: selected == m.userId,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _memberUserId = m.userId),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'PKR '),
                  validator: (v) {
                    final paisa = Money.tryParse(v ?? '');
                    if (paisa == null) return 'Enter a valid amount';
                    if (paisa <= 0) return 'Amount must be more than zero';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(_date.year - 1),
                      lastDate: today(),
                    );
                    if (picked != null) setState(() => _date = dateOnly(picked));
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(AppDates.day(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. October top-up'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recorded by ${s.nameOf(s.viewerUserId)}.',
                  style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Record contribution', busy: _busy, onPressed: _save),
      ),
    );
  }
}
