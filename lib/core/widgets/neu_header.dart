import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../neu/neu.dart';

/// Page header in the neumorphic style: a light title with a small,
/// letter-spaced caption, and round buttons on either side.
class NeuHeader extends StatelessWidget implements PreferredSizeWidget {
  const NeuHeader({
    super.key,
    required this.title,
    this.caption,
    this.leading,
    this.trailing = const [],
    this.centered = false,
    this.showBack = true,
  });

  final String title;

  /// Shown in small capitals under the title.
  final String? caption;
  final Widget? leading;
  final List<Widget> trailing;
  final bool centered;

  /// Show a back button when there is a page to go back to.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final canPop = showBack && GoRouter.of(context).canPop();
    final lead =
        leading ??
        (canPop
            ? NeuIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => context.pop())
            : null);
    final titles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: palette.text, height: 1.15),
        ),
        if (caption != null)
          Text(
            caption!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: palette.muted),
          ),
      ],
    );
    return Material(
      color: palette.base,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 14)],
              Expanded(child: titles),
              for (final (i, action) in trailing.indexed) ...[if (i > 0) const SizedBox(width: 12), action],
              if (centered && trailing.isEmpty && lead != null) const SizedBox(width: 46),
            ],
          ),
        ),
      ),
    );
  }
}
