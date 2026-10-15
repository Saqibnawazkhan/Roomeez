import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';
import '../../../data/mock/mock_auth_repository.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.phone, required this.isSignUp});

  final String phone;
  final bool isSignUp;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      showAppSnack(context, 'Enter the 6-digit code.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      // On success the router redirects to profile setup or home.
      await ref
          .read(authRepositoryProvider)
          .verifyCode(phone: widget.phone, code: _code.text, isSignUp: widget.isSignUp);
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            Text('Enter the code', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Sent to ${PhoneNumber.format(widget.phone)}',
              style: context.text.bodyLarge?.copyWith(color: context.appColors.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Demo code: ${MockAuthRepository.demoCode}',
                  style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
                ),
                TextButton(onPressed: () => _code.text = MockAuthRepository.demoCode, child: const Text('Use it')),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.text.headlineSmall?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(counterText: '', hintText: '------'),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 24),
            BusyButton(label: 'Verify', busy: _busy, onPressed: _verify),
            const SizedBox(height: 8),
            Center(
              child: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Change number')),
            ),
          ],
        ),
      ),
    );
  }
}
