// ignore_for_file: deprecated_member_use
// dynamic_color still hands out material_color_utilities' CorePalette, so we use it too.

import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/widgets.dart';
import 'package:material_color_utilities/material_color_utilities.dart' show CorePalette, TonalPalette;

import 'theme.dart';

const systemPaletteKey = 'system';

/// A [Palette] taken from the phone's wallpaper colours (Material You,
/// Android 12+), using the standard Material 3 tones. Paid and received keep
/// fixed red and green, because those colours carry meaning rather than style.
Palette paletteFromCore(CorePalette p) {
  Color tone(TonalPalette t, int n) => Color(t.get(n));
  return Palette(
    key: systemPaletteKey,
    name: 'Wallpaper',
    ink: tone(p.primary, 10),
    accent: tone(p.primary, 40),
    accentD: tone(p.primary, 80),
    pos: const Color(0xFF157A62),
    posD: const Color(0xFF5FCCA8),
    neg: const Color(0xFFC2362D),
    negD: const Color(0xFFF2867B),
    neutral: tone(p.primary, 90),
    bg: tone(p.neutral, 98),
    bgD: tone(p.neutral, 6),
    text: tone(p.neutral, 10),
    textD: tone(p.neutral, 90),
    muted: tone(p.neutralVariant, 30),
    mutedD: tone(p.neutralVariant, 80),
  );
}

/// The wallpaper palette now, or null where the system has none (Android 11
/// and older, iOS) or the lookup fails. [timeout] stops a stuck lookup from
/// holding up start-up.
Future<Palette?> fetchSystemPalette({Duration? timeout}) async {
  try {
    final lookup = DynamicColorPlugin.getCorePalette();
    final core = await (timeout == null ? lookup : lookup.timeout(timeout));
    return core == null ? null : paletteFromCore(core);
  } catch (_) {
    return null; // no dynamic colour here; the fixed palettes still work
  }
}

/// Supplies the wallpaper palette to [builder] and looks again whenever the
/// app returns to the foreground, which is when a new wallpaper shows up.
class SystemPalette extends StatefulWidget {
  const SystemPalette({super.key, this.initial, required this.builder});

  /// What was found before the app started, so the first frame is right.
  final Palette? initial;
  final Widget Function(BuildContext context, Palette? system) builder;

  @override
  State<SystemPalette> createState() => _SystemPaletteState();
}

class _SystemPaletteState extends State<SystemPalette> with WidgetsBindingObserver {
  late Palette? _palette = widget.initial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initial == null) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final next = await fetchSystemPalette();
    if (!mounted || _same(_palette, next)) return;
    setState(() => _palette = next);
  }

  static bool _same(Palette? a, Palette? b) => a == null || b == null ? a == b : a.accent == b.accent && a.accentD == b.accentD && a.bg == b.bg && a.bgD == b.bgD && a.ink == b.ink;

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}
