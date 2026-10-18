import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/neu/neu.dart';
import '../../../core/widgets/common.dart';
import '../widgets/sample_user_sheet.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NeuPalette.of(context);
    final google = ref.watch(authRepositoryProvider).supportsGoogle;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: ConstrainedBox(
              // Minus the vertical padding; never negative (e.g. on the first frame).
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity)),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    // The Roomeez wordmark on a raised card.
                    NeuBox(
                      radius: 36,
                      depth: 10,
                      padding: const EdgeInsets.fromLTRB(30, 34, 30, 34),
                      child: Image.asset(
                        Theme.of(context).brightness == Brightness.dark
                            ? 'assets/brand/logo_on_dark.png'
                            : 'assets/brand/logo_on_light.png',
                        width: 230,
                        semanticLabel: 'Roomeez',
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Shared expenses,\nmade simple.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, height: 1.2, color: palette.text),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'One clear record for everyone you live with.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, color: palette.muted, height: 1.4),
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    if (google) ...[const _GoogleButton(), const SizedBox(height: 20)],
                    NeuButton(
                      label: 'Continue with email',
                      icon: Icons.mail_outline_rounded,
                      primary: !google,
                      onPressed: () => context.push(Routes.email),
                    ),
                    if (ref.watch(prototypeToolsProvider) != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => showSampleUserSheet(context, ref),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('Try the demo'),
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
    return NeuButton(
      label: 'Continue with Google',
      busy: _busy,
      onPressed: _signIn,
      leading: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Text(
          'G',
          style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
        ),
      ),
    );
  }
}
