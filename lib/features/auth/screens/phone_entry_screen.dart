import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';

/// Sign-up and log-in both start with a phone number.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key, required this.isSignUp});

  final bool isSignUp;

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = PhoneNumber.normalize(_phone.text)!;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).requestCode(phone: phone, isSignUp: widget.isSignUp);
      if (!mounted) return;
      context.push(Routes.verify(phone: phone, isSignUp: widget.isSignUp));
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signUp = widget.isSignUp;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              Text(
                signUp ? 'Create your account' : 'Welcome back',
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                signUp ? 'We\'ll send a code to your mobile number.' : 'Enter your mobile number.',
                style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '0300 1234567',
                  prefixIcon: Icon(Icons.phone_iphone),
                ),
                validator: (value) =>
                    PhoneNumber.normalize(value ?? '') == null ? 'Enter a valid number, e.g. 0300 1234567' : null,
                onFieldSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: 24),
              BusyButton(label: 'Continue', busy: _busy, onPressed: _continue),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.pushReplacement(signUp ? Routes.logIn : Routes.signUp),
                  child: Text(signUp ? 'Already have an account? Log in' : 'New here? Create an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
