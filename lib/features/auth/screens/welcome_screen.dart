import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.push(Routes.signUp),
                        child: const Text('Create an account'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(onPressed: () => context.push(Routes.logIn), child: const Text('Log in')),
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
