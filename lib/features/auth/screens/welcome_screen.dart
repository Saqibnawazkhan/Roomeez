import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import '../widgets/sample_user_sheet.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: ConstrainedBox(
              // Minus the vertical padding; never negative (e.g. on the first frame).
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity)),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const _LogoMark(),
                    const SizedBox(height: 28),
                    Text(
                      'Shared expenses,\nmade simple.',
                      style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'One clear record for everyone you live with.',
                      style: context.text.bodyLarge?.copyWith(color: context.appColors.muted, height: 1.4),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    if (ref.watch(authRepositoryProvider).supportsGoogle) ...[
                      const _GoogleButton(),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(Routes.email),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Continue with email'),
                      ),
                    ),
                    if (ref.watch(prototypeToolsProvider) != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => showSampleUserSheet(context, ref),
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Try the demo'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(13)),
          child: Icon(Icons.home_work_rounded, color: context.colors.onPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        Text('Roomeez', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// "Continue with Google". On success the router moves on by itself.
class _GoogleButton extends ConsumerStatefulWidget {
  const _GoogleButton();

  @override
  ConsumerState<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends ConsumerState<_GoogleButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error) {
      if (mounted) showAppSnack(context, describeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _signIn,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Text(
                      'G',
                      style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(child: Text('Continue with Google', overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}
