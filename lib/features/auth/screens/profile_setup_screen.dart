import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../groups/group_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(currentUserProvider)?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // On success the router moves on to Home.
      await ref.read(authRepositoryProvider).updateProfile(name: _name.text);
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final invitedGroups = ref.watch(myGroupsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use another number'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Text('Set up your profile', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Your name is shown to members of your groups next to the expenses you add.',
                style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
              ),
              const SizedBox(height: 24),
              if (invitedGroups.isNotEmpty) ...[
                InfoBanner(
                  icon: Icons.group_add_outlined,
                  message: invitedGroups.length == 1
                      ? 'A member already added this number to "${invitedGroups.first.name}". You\'ll see it after setup.'
                      : 'Members already added this number to ${invitedGroups.length} groups. You\'ll see them after setup.',
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Enter your full name' : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: user == null ? '' : PhoneNumber.format(user.phone),
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Mobile number (verified)',
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
              ),
              const SizedBox(height: 28),
              BusyButton(label: 'Continue', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
