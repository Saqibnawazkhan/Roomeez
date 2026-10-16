import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    // Supabase email codes are 6 digits by default (up to 8 if configured).
    if (_code.text.trim().length < 6) {
      showAppSnack(context, 'Enter the code from the email.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      // On success the router redirects to profile setup or home.
      await ref.read(authRepositoryProvider).verifyEmailCode(email: widget.email, code: _code.text);
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailCode(widget.email);
      if (mounted) showAppSnack(context, 'New code sent');
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demoCode = ref.watch(prototypeToolsProvider)?.demoCode;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            Text('Check your email', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Enter the code we sent to ${widget.email}',
              style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
            ),
            const SizedBox(height: 16),
            if (demoCode != null)
              Row(
                children: [
                  Text(
                    'Demo code: $demoCode',
                    style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
                  ),
                  TextButton(onPressed: () => _code.text = demoCode, child: const Text('Use it')),
                ],
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 8,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.text.headlineSmall?.copyWith(letterSpacing: 10, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(counterText: '', hintText: '------'),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Verify', busy: _busy, onPressed: _verify),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Sending…' : 'Resend code'),
                ),
                TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Change email')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
