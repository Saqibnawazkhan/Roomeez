import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
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
      showAppSnack(context, 'Added to group fund');
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
      appBar: NeuHeader(title: 'Add to group fund'),
      body: snapshot.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(error: error),
        data: (s) {
          final selected = _memberUserId ?? s.viewerUserId;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const SectionHeader('Who is adding money?', padding: EdgeInsets.fromLTRB(4, 8, 4, 8)),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final m in s.activeMembers)
                      NeuChip(
                        leading: MemberAvatar(name: m.displayName, size: 26),
                        label: m.userId == s.viewerUserId ? 'You' : m.displayName,
                        selected: selected == m.userId,
                        onTap: () => setState(() => _memberUserId = m.userId),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                NeuTextFormField(
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
                NeuPickerField(
                  label: 'Date',
                  value: AppDates.day(_date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(_date.year - 1),
                      lastDate: today(),
                    );
                    if (picked != null) setState(() => _date = dateOnly(picked));
                  },
                ),
                const SizedBox(height: 12),
                NeuTextFormField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. October top-up'),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Add money', busy: _busy, onPressed: _save),
      ),
    );
  }
}
