import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const _LogoMark(),
                    const SizedBox(height: 28),
                    Text(
                      'Shared living,\nclearly recorded.',
                      style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Roomeez helps flatmates, roommates and hostel residents keep one honest record of shared expenses.',
                      style: context.text.bodyLarge?.copyWith(color: context.appColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    const _Point(
                      icon: Icons.receipt_long_outlined,
                      title: 'Itemized expenses',
                      body: 'Every member sees what was bought, by whom, and for how much.',
                    ),
                    const _Point(
                      icon: Icons.verified_user_outlined,
                      title: 'Records you can trust',
                      body: 'Only the person who added an expense can edit it. Nothing gets erased.',
                    ),
                    const _Point(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Period reports',
                      body: 'Share a PDF summary for any date range.',
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
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showSampleUserSheet(context, ref),
                        icon: const Icon(Icons.science_outlined, size: 18),
                        label: const Text('Explore with sample users (prototype)'),
                      ),
                    ),
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

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodyMedium?.copyWith(color: context.appColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
