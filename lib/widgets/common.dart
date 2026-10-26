import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../models.dart';
import '../theme.dart';

/// Tap target that tints to `--color-surface` while pressed (the design's
/// hover/active state).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.color, this.highlight, this.radius = BorderRadius.zero, this.border, this.scaleDown = false, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final Color? color, highlight;
  final BorderRadius radius;
  final BoxBorder? border;
  final bool scaleDown;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final hl = widget.highlight ?? context.c.surface;
    Widget box = Container(
      decoration: BoxDecoration(color: _down && widget.onTap != null ? hl : widget.color, borderRadius: widget.radius, border: widget.border),
      child: widget.child,
    );
    if (widget.scaleDown) box = AnimatedScale(scale: _down ? .97 : 1, duration: const Duration(milliseconds: 120), child: box);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: box,
      ),
    );
  }
}

/// iOS inset-grouped container: card colour, hairline border, 20 radius.
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, required this.children, this.color, this.bordered = true});

  final List<Widget> children;
  final Color? color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(20),
        border: bordered ? Border.all(color: c.line) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A row inside an [InsetGroup]: leading at 16px inset, then content whose
/// bottom hairline starts after the leading element.
class GroupRow extends StatelessWidget {
  const GroupRow({super.key, this.leading, required this.child, this.divider = true, this.onTap, this.minHeight = 52, this.padding = const EdgeInsets.only(right: 16), this.gap = 12});

  final Widget? leading;
  final Widget child;
  final bool divider;
  final VoidCallback? onTap;
  final double minHeight, gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(width: 16),
          if (leading != null) ...[Center(child: leading), SizedBox(width: gap)],
          Expanded(
            child: Container(
              padding: padding,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: divider ? c.line : const Color(0x00000000)))),
              child: child,
            ),
          ),
        ]),
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = context.c.avatar(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: a.tint, shape: BoxShape.circle),
      child: Text(initials(name), style: ts(15, w: 700, color: a.fg)),
    );
  }
}

/// Small grey section caption above a group, e.g. "People".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final st = ts(13, w: 600, color: context.c.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [Expanded(child: Text(text, style: st)), if (trailing != null) Text(trailing!, style: st)]),
    );
  }
}

class Chevron extends StatelessWidget {
  const Chevron({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => Ico(Ico.chevron, size: size, color: context.c.muted, stroke: 2.5);
}

/// Full-width filled button in the accent colour.
class AccentButton extends StatelessWidget {
  const AccentButton(this.label, {super.key, required this.onTap, this.height = 52, this.padding = EdgeInsets.zero});

  final String label;
  final VoidCallback onTap;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      color: c.accent,
      highlight: c.accent600,
      radius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: padding,
        alignment: Alignment.center,
        child: Text(label, style: ts(17, w: 700, color: const Color(0xFFFFFFFF))),
      ),
    );
  }
}

/// Card-coloured button used for "Log out" and "Delete transaction".
class CardButton extends StatelessWidget {
  const CardButton(this.label, {super.key, required this.onTap, required this.color});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      color: c.card,
      radius: BorderRadius.circular(20),
      border: Border.all(color: c.line),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        child: Text(label, style: ts(17, w: 600, color: color)),
      ),
    );
  }
}

/// iOS-style 51×31 switch with a springy thumb.
class LedgerSwitch extends StatelessWidget {
  const LedgerSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 51,
          height: 31,
          decoration: BoxDecoration(color: value ? c.accent : c.swOff, borderRadius: BorderRadius.circular(999)),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(.3, 1.35, .5, 1),
              top: 2,
              left: value ? 22 : 2,
              child: Container(
                width: 27,
                height: 27,
                decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: Color(0x26000000), offset: Offset(0, 3), blurRadius: 8),
                  BoxShadow(color: Color(0x29000000), offset: Offset(0, 1), blurRadius: 1),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// iOS segmented control.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.segBg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Semantics(
              button: true,
              selected: options[i].$1 == value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minHeight: 36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: options[i].$1 == value ? c.card : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: options[i].$1 == value
                        ? const [BoxShadow(color: Color(0x24131A26), offset: Offset(0, 1), blurRadius: 3), BoxShadow(color: Color(0x0F131A26), offset: Offset(0, 1), blurRadius: 1)]
                        : const [],
                  ),
                  child: Text(options[i].$2, style: ts(14, w: 600, color: options[i].$1 == value ? c.text : c.muted)),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Centered icon disc used by the empty states.
class IconDisc extends StatelessWidget {
  const IconDisc({super.key, required this.icon, required this.size, required this.iconSize});

  final String icon;
  final double size, iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accent100, shape: BoxShape.circle),
      child: Ico(icon, size: iconSize, color: c.accent),
    );
  }
}
