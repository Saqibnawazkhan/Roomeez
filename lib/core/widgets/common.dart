import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../errors/app_exception.dart';
import '../neu/neu.dart';
import '../utils/money.dart';

/// Amount text with tabular figures so columns of numbers line up.
class AmountText extends StatelessWidget {
  const AmountText(
    this.paisa, {
    super.key,
    this.style,
    this.signed = false,
    this.colorize = false,
    this.strikethrough = false,
    this.withCurrency = true,
    this.roundToRupee = false,
    this.textAlign,
  });

  final int paisa;
  final TextStyle? style;
  final bool signed;

  /// Green for positive, red for negative.
  final bool colorize;
  final bool strikethrough;
  final bool withCurrency;

  /// Show whole rupees only, e.g. for balances.
  final bool roundToRupee;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (colorize && paisa != 0) {
      color = paisa > 0 ? context.appColors.positive : context.appColors.negative;
    }
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      Money.format(paisa, signed: signed, withCurrency: withCurrency, roundToRupee: roundToRupee),
      textAlign: textAlign,
      style: base.copyWith(
        color: color ?? base.color,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: strikethrough ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

/// A raised neumorphic card, optionally tappable (it presses in on touch).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Ignored in the neumorphic design (every surface shares one color);
  /// kept so existing call sites compile.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return NeuBox(padding: padding, child: child);
    return NeuPressable(onTap: onTap, padding: padding, child: child);
  }
}

/// Small, letter-spaced section title.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => NeuSectionLabel(title, trailing: trailing, padding: padding);
}

/// Initials in a colored circle; color is stable per name.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.size = 40, this.muted = false});

  final String name;
  final double size;
  final bool muted;

  static const _palette = [
    Color(0xFF2FAFAD),
    Color(0xFF6A78E8),
    Color(0xFFE08A3C),
    Color(0xFFD2668E),
    Color(0xFF3E95CF),
    Color(0xFF9A6BDB),
    Color(0xFF3FA36E),
  ];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? context.appColors.muted
        : _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    // A raised ring around a soft colored disc with the initials.
    return NeuBox(
      circle: true,
      depth: size / 12,
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
        child: Text(
          initials(name),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: size * 0.32),
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. "You", "Manager", "Edited".
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { info, warning, prototype, fund }

/// An inline explanatory message.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.tone = BannerTone.info, this.icon, this.action});

  final String message;
  final BannerTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final defaultIcon = switch (tone) {
      BannerTone.info => Icons.info_outline,
      BannerTone.warning => Icons.warning_amber_rounded,
      BannerTone.prototype => Icons.science_outlined,
      BannerTone.fund => Icons.savings_outlined,
    };
    final iconColor = tone == BannerTone.warning ? context.colors.error : NeuPalette.of(context).accent;
    return NeuBox(
      style: NeuStyle.inset,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: context.text.bodyMedium?.copyWith(height: 1.4)),
                if (action != null) ...[const SizedBox(height: 6), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuBox(
            circle: true,
            width: 72,
            height: 72,
            child: Icon(icon, size: 30, color: NeuPalette.of(context).accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.appColors.muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.action});

  final Object error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final noAccess = error is PermissionDeniedException;
    return Center(
      child: EmptyState(
        icon: noAccess ? Icons.lock_outline : Icons.cloud_off_outlined,
        title: noAccess ? 'No access' : 'Couldn\'t load this',
        message: describeError(error),
        action: action,
      ),
    );
  }
}

/// A full-width filled button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => NeuButton(label: label, onPressed: onPressed, busy: busy, icon: icon);
}

/// Label above a value, used in detail screens.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelMedium?.copyWith(color: context.appColors.muted)),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          child: value,
        ),
      ],
    );
  }
}

/// A bottom area for primary actions that respects the safe area.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 16), child: child),
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 2500),
      backgroundColor: isError ? context.colors.error : null,
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                  minimumSize: const Size(64, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
