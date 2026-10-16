import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/neu_header.dart';

/// Sign in or sign up with a code sent by email.
class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailCode(email);
      if (!mounted) return;
      context.push(Routes.verify(email: email));
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NeuHeader(title: ''),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Text('Continue with email', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'We\'ll email you a code. No password needed.',
                style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
              ),
              const SizedBox(height: 28),
              NeuTextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@gmail.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) =>
                    _emailPattern.hasMatch((value ?? '').trim()) ? null : 'Enter a valid email address',
                onFieldSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: 24),
              BusyButton(label: 'Send code', busy: _busy, onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }
}
