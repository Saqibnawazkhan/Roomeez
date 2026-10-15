import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/phone.dart';
import '../../../core/widgets/common.dart';

/// PROTOTYPE ONLY. Lets testers switch between sample accounts to check
/// permissions (e.g. that only an expense's creator sees "Edit").
Future<void> showSampleUserSheet(BuildContext context, WidgetRef ref) {
  final tools = ref.read(prototypeToolsProvider);
  final currentId = ref.read(currentUserIdProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sample users', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const InfoBanner(
              tone: BannerTone.prototype,
              message:
                  'Prototype feature. Switch accounts to see what each member can do. '
                  'Data is sample data kept on this device only and resets when the app restarts.',
            ),
            const SizedBox(height: 8),
            for (final user in tools.sampleUsers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MemberAvatar(name: user.name),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(PhoneNumber.format(user.phone)),
                trailing: user.id == currentId ? const Pill('Current') : const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await tools.signInAs(user.id);
                  if (context.mounted) context.go(Routes.home);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
