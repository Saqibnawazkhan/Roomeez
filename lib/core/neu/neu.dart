import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/haptics.dart';

// -----------------------------------------------------------------------------
// Neumorphism: every surface has the background color and is shaped only by
// light. A raised element has a light shadow up-left and a dark shadow
// down-right; an inset (pressed) element has them inside its edges.
// -----------------------------------------------------------------------------

/// Colors of the neumorphic surface. Read with `NeuPalette.of(context)`.
@immutable
class NeuPalette extends ThemeExtension<NeuPalette> {
  const NeuPalette({
    required this.base,
    required this.highlight,
    required this.shade,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
  });

  /// The one surface color everything is made of.
  final Color base;

  /// Light shadow (top-left).
  final Color highlight;

  /// Dark shadow (bottom-right).
  final Color shade;
  final Color text;
  final Color muted;

  /// Teal accent for icons, selected states and primary actions.
  final Color accent;

  /// The light end of the accent gradient.
  final Color accentSoft;

  LinearGradient get accentGradient =>
      LinearGradient(colors: [accent, accentSoft], begin: Alignment.centerLeft, end: Alignment.centerRight);

  static const NeuPalette light = NeuPalette(
    base: Color(0xFFE6EBF1),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFA9B6C9),
    text: Color(0xFF3B4555),
    muted: Color(0xFF8A95A6),
    accent: Color(0xFF2FAFAD),
    accentSoft: Color(0xFF9FE6E3),
  );

  static const NeuPalette dark = NeuPalette(
    base: Color(0xFF2C3038),
    highlight: Color(0xFF383D46),
    shade: Color(0xFF1C1F24),
    text: Color(0xFFE3E7EE),
    muted: Color(0xFF98A1AE),
    accent: Color(0xFF56D0CC),
    accentSoft: Color(0xFF2E7E7C),
  );

  static NeuPalette of(BuildContext context) => Theme.of(context).extension<NeuPalette>() ?? light;

  /// A raised element's two shadows. A colored element passes its [tint] so
  /// its dark shadow glows softly in that color.
  List<BoxShadow> raised([double depth = 6, Color? tint]) => [
    BoxShadow(color: highlight, offset: Offset(-depth, -depth), blurRadius: depth * 2.2),
    BoxShadow(
      color: tint == null ? shade.withValues(alpha: 0.55) : tint.withValues(alpha: 0.4),
      offset: Offset(depth, depth),
      blurRadius: depth * 2.2,
    ),
  ];

  /// A pale version of [hue] on this surface, for icon discs and soft fills.
  Color tint(Color hue, [double amount = 0.16]) => Color.lerp(base, hue, amount)!;

  @override
  NeuPalette copyWith({
    Color? base,
    Color? highlight,
    Color? shade,
    Color? text,
    Color? muted,
    Color? accent,
    Color? accentSoft,
  }) {
    return NeuPalette(
      base: base ?? this.base,
      highlight: highlight ?? this.highlight,
      shade: shade ?? this.shade,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  NeuPalette lerp(NeuPalette? other, double t) {
    if (other == null) return this;
    return NeuPalette(
      base: Color.lerp(base, other.base, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

/// Soft accent hues. Each part of the app has its own so screens feel alive
/// without getting loud: icons sit in pale discs of their hue, and a few key
/// cards use its gradient.
abstract final class NeuHues {
  static const teal = Color(0xFF2FAFAD);
  static const indigo = Color(0xFF6A78E8);
  static const coral = Color(0xFFEE8A6A);
  static const amber = Color(0xFFE5A03A);
  static const violet = Color(0xFF9A6BDB);
  static const sky = Color(0xFF3E95CF);
  static const green = Color(0xFF3FA36E);
  static const rose = Color(0xFFD2668E);

  static const _named = [teal, indigo, coral, violet, sky, amber, green, rose];

  /// A stable hue for something without its own, e.g. a group.
  static Color forName(String name) => _named[name.codeUnits.fold<int>(0, (a, b) => a + b) % _named.length];

  /// [hue] fading to a lighter version of itself.
  static LinearGradient gradient(Color hue) => LinearGradient(
    colors: [hue, Color.lerp(hue, Colors.white, 0.42)!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

enum NeuStyle { raised, inset, flat }

/// A neumorphic surface: raised (default), pressed in (inset) or flat.
class NeuBox extends StatelessWidget {
  const NeuBox({
    super.key,
    this.child,
    this.style = NeuStyle.raised,
    this.radius = 22,
    this.circle = false,
    this.depth = 6,
    this.padding,
    this.width,
    this.height,
    this.gradient,
  });

  final Widget? child;
  final NeuStyle style;
  final double radius;
  final bool circle;
  final double depth;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// Optional fill, e.g. the accent gradient.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    if (style == NeuStyle.inset) {
      return SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _InsetPainter(palette: palette, radius: radius, circle: circle, depth: depth * 0.7),
          child: content,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null ? palette.base : null,
        gradient: gradient,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        boxShadow: style == NeuStyle.raised ? palette.raised(depth, gradient?.colors.first) : null,
      ),
      child: content,
    );
  }
}

/// A small raised disc with a pale [color] fill and the icon in [color].
class NeuIconDisc extends StatelessWidget {
  const NeuIconDisc({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuBox(
      circle: true,
      depth: size / 12,
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: palette.tint(color)),
        child: Center(
          child: Icon(icon, size: size * 0.42, color: color),
        ),
      ),
    );
  }
}

/// Inner shadows: dark along the top-left inner edge, light along the
/// bottom-right, as if the area were pressed into the surface.
class _InsetPainter extends CustomPainter {
  _InsetPainter({required this.palette, required this.radius, required this.circle, required this.depth});

  final NeuPalette palette;
  final double radius;
  final bool circle;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = circle ? size.shortestSide / 2 : radius;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.drawRRect(shape, Paint()..color = palette.base);
    canvas.save();
    canvas.clipRRect(shape);
    void inner(Color color, Offset offset) {
      final frame = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(depth * 6))
        ..addRRect(shape.shift(offset));
      canvas.drawPath(
        frame,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth),
      );
    }

    inner(palette.shade.withValues(alpha: 0.6), Offset(depth, depth));
    inner(palette.highlight, Offset(-depth, -depth));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.palette != palette || old.radius != radius || old.circle != circle || old.depth != depth;
}

/// A raised surface that presses in while touched (or stays pressed when
/// [selected]).
class NeuPressable extends StatefulWidget {
  const NeuPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.radius = 22,
    this.circle = false,
    this.depth = 6,
    this.padding,
    this.width,
    this.height,
    this.semanticLabel,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;
  final bool circle;
  final double depth;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final String? semanticLabel;

  /// A colored fill; such a surface flattens instead of pressing in.
  final Gradient? gradient;

  @override
  State<NeuPressable> createState() => _NeuPressableState();
}

class _NeuPressableState extends State<NeuPressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (widget.onTap == null || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down || widget.selected;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap == null
            ? null
            : () {
                Haptics.tap();
                widget.onTap!();
              },
        child: Opacity(
          opacity: widget.onTap == null && !widget.selected ? 0.55 : 1,
          child: NeuBox(
            style: pressed ? (widget.gradient == null ? NeuStyle.inset : NeuStyle.flat) : NeuStyle.raised,
            gradient: widget.gradient,
            radius: widget.radius,
            circle: widget.circle,
            depth: widget.depth,
            padding: widget.padding,
            width: widget.width,
            height: widget.height,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Full-width pill button. [primary] uses the accent gradient.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.busy = false,
    this.primary = true,
    this.destructive = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A custom leading widget (e.g. a logo); takes precedence over [icon].
  final Widget? leading;
  final bool busy;
  final bool primary;
  final bool destructive;
  final double height;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final enabled = widget.onPressed != null && !widget.busy;
    final error = Theme.of(context).colorScheme.error;
    final foreground = widget.primary
        ? Colors.white
        : widget.destructive
        ? error
        : palette.accent;
    final pressed = _down && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                Haptics.tap();
                widget.onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.onPressed == null ? 0.5 : 1,
          child: NeuBox(
            height: widget.height,
            radius: widget.height / 2.6,
            depth: pressed ? 2 : 6,
            style: !widget.primary && pressed ? NeuStyle.inset : NeuStyle.raised,
            gradient: widget.primary ? palette.accentGradient : null,
            child: Center(
              child: widget.busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
                          if (widget.leading == null && widget.icon != null) ...[
                            Icon(widget.icon, size: 20, color: foreground),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w600),
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

/// Round icon button, like the app row in the reference design.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 46,
    this.selected = false,
    this.color,
    this.hue,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool selected;
  final Color? color;

  /// When [selected], the button fills with this hue instead of pressing in.
  final Color? hue;

  /// Replaces the icon (e.g. an avatar).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final filled = selected && hue != null;
    final iconColor = filled ? Colors.white : color ?? (selected ? palette.accent : palette.muted);
    final button = NeuPressable(
      onTap: onPressed,
      selected: selected && !filled,
      gradient: filled ? NeuHues.gradient(hue!) : null,
      circle: true,
      depth: size / 10,
      width: size,
      height: size,
      semanticLabel: tooltip,
      child: Center(
        child: child ?? Icon(icon, size: size * 0.44, color: iconColor),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// A selectable pill: raised when off, pressed in with the accent when on.
class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  /// Fills the space it's given with the content centered, as in a
  /// [NeuChipGrid]; long labels shrink to fit.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        // One smaller size in grids so every chip's text matches.
        fontSize: expand ? 12.5 : 13.5,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? palette.accent : palette.text,
      ),
    );
    return NeuPressable(
      onTap: onTap,
      selected: selected,
      radius: 16,
      depth: 3.5,
      padding: expand
          ? const EdgeInsets.symmetric(horizontal: 8)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, SizedBox(width: expand ? 6 : 8)],
          if (expand)
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: text),
            )
          else
            text,
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// Chips in equal columns, so every chip in a group is the same size.
/// Give the chips `expand: true`.
class NeuChipGrid extends StatelessWidget {
  const NeuChipGrid({super.key, required this.children, this.columns = 3, this.spacing = 12, this.height = 46});

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - spacing * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, height: height, child: child)],
        );
      },
    );
  }
}

/// Two or three options in a pressed-in track; the chosen one is raised.
class NeuSegmented<T> extends StatelessWidget {
  const NeuSegmented({super.key, required this.segments, required this.value, required this.onChanged});

  final List<(T, String, IconData?)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuBox(
      style: NeuStyle.inset,
      radius: 20,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final (segment, label, icon) in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (segment != value) Haptics.select();
                    onChanged(segment);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    decoration: BoxDecoration(
                      color: segment == value ? palette.base : palette.base.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: segment == value ? palette.raised(3) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: segment == value ? palette.accent : palette.muted),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: segment == value ? FontWeight.w600 : FontWeight.w500,
                              color: segment == value ? palette.accent : palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A pressed-in track filled with the accent gradient up to [value] (0–1),
/// with a raised knob, like the slider in the reference design.
class NeuProgress extends StatelessWidget {
  const NeuProgress({super.key, required this.value, this.startLabel, this.endLabel, this.height = 48, this.hue});

  final double value;
  final String? startLabel;
  final String? endLabel;
  final double height;

  /// Fill color; the accent by default.
  final Color? hue;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final v = value.clamp(0.0, 1.0);
    return NeuBox(
      style: NeuStyle.inset,
      radius: height / 2,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final knob = height - 8;
          final fill = (width * v).clamp(knob + 8, width);
          return Stack(
            children: [
              Positioned(
                left: 4,
                top: 4,
                bottom: 4,
                width: fill - 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: hue == null ? palette.accentGradient : NeuHues.gradient(hue!),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              if (startLabel != null)
                // Inside the fill when there is room, otherwise just past the knob.
                Positioned(
                  left: fill - knob - 4 > 64 ? 18 : fill + 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      startLabel!,
                      style: TextStyle(
                        color: fill - knob - 4 > 64 ? Colors.white : hue ?? palette.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (endLabel != null)
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(endLabel!, style: TextStyle(color: palette.muted, fontSize: 13)),
                  ),
                ),
              Positioned(
                left: fill - knob - 4,
                top: 4,
                child: NeuBox(circle: true, depth: 3, width: knob, height: knob),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small, letter-spaced section title, e.g. "RECENT EXPENSES".
class NeuSectionLabel extends StatelessWidget {
  const NeuSectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(6, 26, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(color: palette.muted, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 2.6),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Round raised buttons with small labels, used as the group's bottom
/// navigation.
class NeuBottomNav extends StatelessWidget {
  const NeuBottomNav({super.key, required this.items, required this.index, required this.onTap, this.hues});

  final List<(IconData, String, int)> items;
  final int index;
  final ValueChanged<int> onTap;

  /// One hue per item; the selected item fills with its hue.
  final List<Color>? hues;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Material(
      color: palette.base,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (i, (icon, label, badge)) in items.indexed)
                Expanded(
                  child: Semantics(
                    label: label,
                    selected: i == index,
                    button: true,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Haptics.select();
                        onTap(i);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Badge(
                            isLabelVisible: badge > 0,
                            label: Text('$badge'),
                            offset: const Offset(-2, 2),
                            child: NeuIconButton(
                              icon: icon,
                              onPressed: () => onTap(i),
                              selected: i == index,
                              hue: hues?[i],
                              size: 50,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label.toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                                color: i == index ? (hues?[i] ?? palette.accent) : palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _flat(InputDecoration? decoration) => (decoration ?? const InputDecoration()).copyWith(
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  filled: false,
  contentPadding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
);

/// A form field pressed into the surface.
class NeuTextFormField extends StatelessWidget {
  const NeuTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.decoration,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.enabled,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool? enabled;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return NeuBox(
      style: NeuStyle.inset,
      radius: 18,
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        decoration: _flat(decoration),
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        autofocus: autofocus,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        enabled: enabled,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// A text field pressed into the surface.
class NeuTextField extends StatelessWidget {
  const NeuTextField({
    super.key,
    this.controller,
    this.decoration,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.enabled,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool? enabled;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return NeuBox(
      style: NeuStyle.inset,
      radius: 18,
      child: TextField(
        controller: controller,
        decoration: _flat(decoration),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        enabled: enabled,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// A pressed-in field that opens a picker (e.g. a date) when tapped.
class NeuPickerField extends StatelessWidget {
  const NeuPickerField({super.key, required this.label, required this.value, required this.onTap, this.icon});

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: NeuBox(
          style: NeuStyle.inset,
          radius: 18,
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: palette.muted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: palette.text, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Icon(icon ?? Icons.calendar_today_outlined, size: 20, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}
