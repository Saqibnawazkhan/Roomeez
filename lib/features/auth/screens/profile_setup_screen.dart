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
import '../../groups/group_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone == null ? '' : PhoneNumber.format(user!.phone!));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // On success the router moves on to Home.
      await ref
          .read(authRepositoryProvider)
          .updateProfile(name: _name.text, phone: PhoneNumber.normalizeOptional(_phone.text));
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitedGroups = ref.watch(myGroupsProvider).value ?? const [];
    return Scaffold(
      appBar: NeuHeader(
        title: '',
        showBack: false,
        trailing: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use another account'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Text('What\'s your name?', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Your group members will see this name.',
                style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
              ),
              const SizedBox(height: 24),
              if (invitedGroups.isNotEmpty) ...[
                InfoBanner(
                  icon: Icons.group_add_outlined,
                  message: invitedGroups.length == 1
                      ? 'You\'ve been added to "${invitedGroups.first.name}".'
                      : 'You\'ve been added to ${invitedGroups.length} groups.',
                ),
                const SizedBox(height: 16),
              ],
              NeuTextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 16),
              NeuTextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                decoration: const InputDecoration(
                  labelText: 'Mobile number (optional)',
                  hintText: '0300 1234567',
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
                validator: PhoneNumber.optionalFieldError,
                onFieldSubmitted: (_) => _save(),
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
