import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/neu/neu.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/repositories/group_repository.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A member added on this screen, before the group exists.
class _NewMember {
  _NewMember({required this.name, this.email, this.phone});

  String name;
  String? email;
  String? phone;
  final contribution = TextEditingController();

  void dispose() => contribution.dispose();
}

typedef _MemberDetails = ({String name, String? email, String? phone});

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _myContribution = TextEditingController();
  final List<_NewMember> _members = [];
  bool _withFund = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _myContribution.dispose();
    for (final member in _members) {
      member.dispose();
    }
    super.dispose();
  }

  int get _fundTotal {
    var total = Money.tryParse(_myContribution.text) ?? 0;
    for (final member in _members) {
      total += Money.tryParse(member.contribution.text) ?? 0;
    }
    return total;
  }

  String? _amountValidator(String? value) {
    if (!_withFund || (value ?? '').trim().isEmpty) return null;
    return Money.tryParse(value!) == null ? 'Invalid amount' : null;
  }

  /// Opens the member sheet; edits [existing] or adds a new member.
  Future<void> _editMember([_NewMember? existing]) async {
    final user = ref.read(currentUserProvider);
    final taken = {
      ?user?.email?.toLowerCase(),
      for (final m in _members)
        if (m != existing && m.email != null) m.email!,
    };
    final details = await showModalBottomSheet<_MemberDetails>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MemberSheet(existing: existing, takenEmails: taken),
    );
    if (details == null || !mounted) return;
    setState(() {
      if (existing == null) {
        _members.add(_NewMember(name: details.name, email: details.email, phone: details.phone));
      } else {
        existing
          ..name = details.name
          ..email = details.email
          ..phone = details.phone;
      }
    });
  }

  void _removeMember(_NewMember member) {
    setState(() => _members.remove(member));
    member.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .createGroup(
            actorUserId: user.id,
            input: NewGroupInput(
              name: _name.text,
              description: _description.text,
              members: [
                for (final m in _members)
                  NewMemberInput(
                    name: m.name,
                    email: m.email,
                    phone: m.phone,
                    initialContributionPaisa: _withFund ? Money.tryParse(m.contribution.text) ?? 0 : 0,
                  ),
              ],
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
    final palette = NeuPalette.of(context);
    final user = ref.watch(currentUserProvider);
    final myName = user?.name ?? 'You';

    return Scaffold(
      appBar: NeuHeader(title: 'Create group'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // Group details, with an icon that takes the group's color as you type.
            NeuBox(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _name,
                        builder: (context, value, _) => NeuIconDisc(
                          icon: Icons.home_work_rounded,
                          color: value.text.trim().isEmpty ? NeuHues.teal : NeuHues.forName(value.text.trim()),
                          size: 54,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group details',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.text),
                            ),
                            Text('Your flat, room or hostel', style: TextStyle(fontSize: 12.5, color: palette.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  NeuTextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. My Apartment'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a group name' : null,
                  ),
                  const SizedBox(height: 14),
                  NeuTextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Short description (optional)'),
                  ),
                ],
              ),
            ),

            NeuSectionLabel(
              'Members',
              trailing: Text(
                '${_members.length + 1}',
                style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
              ),
            ),
            _PersonRow(
              name: '$myName (you)',
              avatarName: myName,
              subtitle: user?.email ?? 'Group manager',
              trailing: const Pill('Manager', color: NeuHues.teal),
            ),
            for (final member in _members)
              _PersonRow(
                name: member.name,
                avatarName: member.name,
                subtitle: member.email ?? (member.phone == null ? 'No email' : PhoneNumber.format(member.phone!)),
                onTap: () => _editMember(member),
                trailing: NeuIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove ${member.name}',
                  size: 36,
                  onPressed: () => _removeMember(member),
                ),
              ),
            NeuPressable(
              onTap: _editMember,
              radius: 30,
              padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
              child: Row(
                children: [
                  const NeuIconDisc(icon: Icons.person_add_alt_1_rounded, color: NeuHues.indigo, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add member',
                          style: TextStyle(color: NeuHues.indigo, fontWeight: FontWeight.w600),
                        ),
                        Text('You can also add people later', style: TextStyle(fontSize: 12, color: palette.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_rounded, color: NeuHues.indigo),
                ],
              ),
            ),

            const NeuSectionLabel('Group fund'),
            NeuBox(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const NeuIconDisc(icon: Icons.savings_rounded, color: NeuHues.violet, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start with a group fund',
                              style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
                            ),
                            Text('Optional money pool', style: TextStyle(fontSize: 12, color: palette.muted)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _withFund,
                        activeTrackColor: NeuHues.violet,
                        onChanged: (v) => setState(() => _withFund = v),
                      ),
                    ],
                  ),
                  if (_withFund) ...[
                    const SizedBox(height: 16),
                    _ContributionRow(
                      name: myName,
                      controller: _myContribution,
                      validator: _amountValidator,
                      onChanged: () => setState(() {}),
                    ),
                    for (final member in _members)
                      _ContributionRow(
                        name: member.name,
                        controller: member.contribution,
                        validator: _amountValidator,
                        onChanged: () => setState(() {}),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: palette.tint(NeuHues.violet, 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Fund total',
                              style: TextStyle(color: NeuHues.violet, fontWeight: FontWeight.w600),
                            ),
                          ),
                          AmountText(
                            _fundTotal,
                            style: const TextStyle(color: NeuHues.violet, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Create group', busy: _busy, onPressed: _create),
      ),
    );
  }
}

/// A person in the member list: avatar, name and contact, like the Members tab.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, required this.avatarName, required this.subtitle, this.trailing, this.onTap});

  final String name;
  final String avatarName;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final content = Row(
      children: [
        MemberAvatar(name: avatarName, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    const padding = EdgeInsets.fromLTRB(10, 10, 12, 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: onTap == null
          ? NeuBox(radius: 30, padding: padding, child: content)
          : NeuPressable(onTap: onTap, radius: 30, padding: padding, child: content),
    );
  }
}

/// One person's starting amount for the group fund.
class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.name,
    required this.controller,
    required this.validator,
    required this.onChanged,
  });

  final String name;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Row(
        children: [
          MemberAvatar(name: name, size: 34),
          const SizedBox(width: 12),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: NeuTextFormField(
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

/// Name, email and mobile for one member, in a bottom sheet.
class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.existing, required this.takenEmails});

  final _NewMember? existing;

  /// Emails already used by you or another member.
  final Set<String> takenEmails;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(
    text: widget.existing?.phone == null ? null : PhoneNumber.format(widget.existing!.phone!),
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    Navigator.of(context).pop<_MemberDetails>((
      name: _name.text.trim(),
      email: email.isEmpty ? null : email,
      phone: PhoneNumber.normalizeOptional(_phone.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, value, _) => value.text.trim().isEmpty
                      ? const NeuIconDisc(icon: Icons.person_rounded, color: NeuHues.indigo, size: 48)
                      : MemberAvatar(name: value.text.trim(), size: 48),
                ),
                const SizedBox(width: 14),
                Text(
                  editing ? 'Edit member' : 'Add member',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: palette.text),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NeuTextFormField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            NeuTextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final text = (v ?? '').trim().toLowerCase();
                if (text.isEmpty) return null;
                if (!_emailPattern.hasMatch(text)) return 'Enter a valid email';
                return widget.takenEmails.contains(text) ? 'Someone in this group already uses this email' : null;
              },
            ),
            const SizedBox(height: 14),
            NeuTextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
              decoration: const InputDecoration(
                labelText: 'Mobile number (optional)',
                hintText: '0300 1234567',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
              validator: PhoneNumber.optionalFieldError,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'With an email, they join this group automatically when they sign in.',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
            const SizedBox(height: 20),
            NeuButton(label: editing ? 'Save' : 'Add member', icon: Icons.check_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
