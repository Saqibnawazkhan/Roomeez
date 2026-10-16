import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';
import '../../../data/models/models.dart';
import '../../auth/widgets/sample_user_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, AppUser user) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _ProfileDialog(user: user),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).updateProfile(name: result.$1, phone: result.$2);
      if (context.mounted) showAppSnack(context, 'Profile updated');
    } catch (error) {
      if (context.mounted) showAppSnack(context, describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final muted = context.text.bodyLarge?.copyWith(color: context.appColors.muted);
    return Scaffold(
      appBar: NeuHeader(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: MemberAvatar(name: user.name, size: 84)),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
          ),
          if (user.email != null) Text(user.email!, textAlign: TextAlign.center, style: muted),
          if (user.phone != null) Text(PhoneNumber.format(user.phone!), textAlign: TextAlign.center, style: muted),
          const SizedBox(height: 24),
          NeuBox(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit profile'),
              subtitle: const Text('Name, mobile number'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _edit(context, ref, user),
            ),
          ),
          if (ref.watch(prototypeToolsProvider) != null) ...[
            const SectionHeader('Demo'),
            NeuBox(
              child: ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Switch demo user'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showSampleUserSheet(context, ref),
              ),
            ),
          ],
          const SizedBox(height: 24),
          NeuButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            primary: false,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.user});

  final AppUser user;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.user.name);
  late final TextEditingController _phone = TextEditingController(
    text: widget.user.phone == null ? '' : PhoneNumber.format(widget.user.phone!),
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuTextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 12),
            NeuTextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
              decoration: const InputDecoration(labelText: 'Mobile number (optional)', hintText: '0300 1234567'),
              validator: PhoneNumber.optionalFieldError,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((_name.text, PhoneNumber.normalizeOptional(_phone.text)));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
