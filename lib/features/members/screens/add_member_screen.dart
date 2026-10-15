import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/group_repository.dart';

class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  DateTime _startDate = today();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: 'Membership start date',
    );
    if (picked != null) setState(() => _startDate = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final member = await ref
          .read(groupRepositoryProvider)
          .addMember(
            actorUserId: userId,
            groupId: widget.groupId,
            member: NewMemberInput(name: _name.text, phone: PhoneNumber.normalize(_phone.text)!),
            startDate: _startDate,
          );
      if (!mounted) return;
      context.pop();
      showAppSnack(context, '${member.displayName} added. They can sign up with this number to see the group.');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add member')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter their full name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '0300 1234567',
                prefixIcon: Icon(Icons.phone_iphone),
              ),
              validator: (v) => PhoneNumber.normalize(v ?? '') == null ? 'Enter a valid mobile number' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Membership start date',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(AppDates.day(_startDate)),
              ),
            ),
            const SizedBox(height: 16),
            InfoBanner(
              message:
                  'They\'ll share expenses dated from ${AppDates.day(_startDate)} onward. '
                  'Expenses from before that date aren\'t assigned to them.',
            ),
            const SizedBox(height: 8),
            Text(
              'If they don\'t have Roomeez yet, they\'ll see this group as soon as they sign up with this number.',
              style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyButton(label: 'Add member', busy: _busy, onPressed: _save),
      ),
    );
  }
}
