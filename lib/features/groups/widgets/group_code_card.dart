import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';

/// Shows the join code with copy and share actions.
class GroupCodeCard extends StatelessWidget {
  const GroupCodeCard({super.key, required this.group, this.trailing});

  final Group group;
  final Widget? trailing;

  static String shareText(Group group) =>
      'Join "${group.name}" on Roomeez to see and add our shared expenses. Group code: ${group.code}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text('Group code', style: context.text.labelLarge?.copyWith(color: context.appColors.muted)),
          const SizedBox(height: 8),
          SelectableText(
            group.code,
            style: context.text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'People who join with this code need approval from a member.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.appColors.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: group.code));
                    if (context.mounted) showAppSnack(context, 'Code ${group.code} copied');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: shareText(group), subject: 'Join ${group.name} on Roomeez'),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 4), trailing!],
        ],
      ),
    );
  }
}
