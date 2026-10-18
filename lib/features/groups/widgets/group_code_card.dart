import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/neu/neu.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';

/// Shows the join code with copy and share actions.
class GroupCodeCard extends StatefulWidget {
  const GroupCodeCard({super.key, required this.group, this.trailing});

  final Group group;
  final Widget? trailing;

  static String shareText(Group group) =>
      'Join "${group.name}" on Roomeez to see and add our shared expenses. Group code: ${group.code}';

  @override
  State<GroupCodeCard> createState() => _GroupCodeCardState();
}

class _GroupCodeCardState extends State<GroupCodeCard> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  // Android already shows its own "Copied" toast, so confirm on the button
  // itself instead of adding a second message.
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.group.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return AppCard(
      child: Column(
        children: [
          Text('Group code', style: context.text.labelLarge?.copyWith(color: context.appColors.muted)),
          const SizedBox(height: 8),
          SelectableText(
            group.code,
            style: context.text.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
              color: NeuHues.amber,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: _copied ? 'Copied' : 'Copy',
                  icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                  primary: false,
                  height: 50,
                  onPressed: _copy,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NeuButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  height: 50,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: GroupCodeCard.shareText(group), subject: 'Join ${group.name} on Roomeez'),
                  ),
                ),
              ),
            ],
          ),
          if (widget.trailing != null) ...[const SizedBox(height: 4), widget.trailing!],
        ],
      ),
    );
  }
}
