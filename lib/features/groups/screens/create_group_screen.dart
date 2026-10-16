import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/group_repository.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _MemberRow {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final contribution = TextEditingController();

  bool get isBlank => name.text.trim().isEmpty && email.text.trim().isEmpty && phone.text.trim().isEmpty;

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    contribution.dispose();
  }
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _myContribution = TextEditingController();
  final List<_MemberRow> _rows = [_MemberRow()];
  bool _withFund = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _myContribution.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool _rowIsBlank(_MemberRow row) => row.isBlank;

  int get _fundTotal {
    var total = Money.tryParse(_myContribution.text) ?? 0;
    for (final row in _rows) {
      if (!_rowIsBlank(row)) total += Money.tryParse(row.contribution.text) ?? 0;
    }
    return total;
  }

  String? _amountValidator(String? value) {
    if (!_withFund || (value ?? '').trim().isEmpty) return null;
    return Money.tryParse(value!) == null ? 'Invalid amount' : null;
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final members = <NewMemberInput>[];
    final seenEmails = <String>{?user.email};
    for (final row in _rows) {
      if (_rowIsBlank(row)) continue;
      final email = row.email.text.trim().toLowerCase();
      if (email.isNotEmpty && !seenEmails.add(email)) {
        showAppSnack(context, 'Each member needs a different email.', isError: true);
        return;
      }
      members.add(
        NewMemberInput(
          name: row.name.text.trim(),
          email: email.isEmpty ? null : email,
          phone: PhoneNumber.normalizeOptional(row.phone.text),
          initialContributionPaisa: _withFund ? Money.tryParse(row.contribution.text) ?? 0 : 0,
        ),
      );
    }

    setState(() => _busy = true);
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .createGroup(
            actorUserId: user.id,
            input: NewGroupInput(
              name: _name.text,
              description: _description.text,
              members: members,
              myContributionPaisa: _withFund ? Money.tryParse(_myContribution.text) ?? 0 : 0,
            ),
          );
      if (!mounted) return;
      context.pushReplacement(Routes.groupCreated(group.id));
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. My Apartment'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a group name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Short description (optional)'),
            ),
            const SectionHeader('Members'),
            AppCard(
              child: Row(
                children: [
                  MemberAvatar(name: user?.name ?? '?'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user?.name ?? ''} (you)', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Group manager', style: context.text.bodySmall?.copyWith(color: context.appColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final (index, row) in _rows.indexed) ...[
              _MemberFields(
                key: ObjectKey(row),
                row: row,
                index: index,
                canRemove: _rows.length > 1,
                onChanged: () {
                  if (_withFund) setState(() {});
                },
                onRemove: () => setState(() {
                  _rows.remove(row);
                  row.dispose();
                }),
              ),
              const SizedBox(height: 10),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _rows.add(_MemberRow())),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add another member'),
              ),
            ),

            const SectionHeader('Group fund'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SwitchListTile(
                value: _withFund,
                onChanged: (v) => setState(() => _withFund = v),
                title: const Text('Start with a group fund', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Optional shared money pool'),
              ),
            ),
            if (_withFund) ...[
              const SizedBox(height: 12),
              _ContributionField(
                label: '${user?.name ?? 'You'} (you)',
                controller: _myContribution,
                validator: _amountValidator,
                onChanged: () => setState(() {}),
              ),
              for (final row in _rows)
                if (!_rowIsBlank(row))
                  _ContributionField(
                    label: row.name.text.trim().isEmpty ? 'New member' : row.name.text.trim(),
                    controller: row.contribution,
                    validator: _amountValidator,
                    onChanged: () => setState(() {}),
                  ),
              const SizedBox(height: 4),
              InfoBanner(tone: BannerTone.fund, message: 'Fund total: ${Money.format(_fundTotal)}'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Create group', busy: _busy, onPressed: _create),
      ),
    );
  }
}

class _MemberFields extends StatelessWidget {
  const _MemberFields({
    super.key,
    required this.row,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _MemberRow row;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  bool get _blank => row.isBlank;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      child: Column(
        children: [
          // Fixed height so the first field's floating label never overlaps the header.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Member ${index + 1}',
                    style: context.text.labelLarge?.copyWith(color: context.appColors.muted),
                  ),
                ),
                if (canRemove)
                  IconButton(tooltip: 'Remove this row', onPressed: onRemove, icon: const Icon(Icons.close, size: 20)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                TextFormField(
                  controller: row.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', isDense: true),
                  validator: (v) => !_blank && (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: row.email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'They join when they sign in with it',
                    isDense: true,
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    return text.isEmpty || _emailPattern.hasMatch(text) ? null : 'Enter a valid email';
                  },
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: row.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number (optional)',
                    hintText: '0300 1234567',
                    isDense: true,
                  ),
                  validator: PhoneNumber.optionalFieldError,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionField extends StatelessWidget {
  const _ContributionField({
    required this.label,
    required this.controller,
    required this.validator,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(prefixText: 'PKR ', hintText: '0', isDense: true),
              validator: validator,
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
