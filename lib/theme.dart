import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One of the four colour palettes from Settings → Color theme.
class Palette {
  const Palette({
    required this.key,
    required this.name,
    required this.ink,
    required this.accent,
    required this.accentD,
    required this.pos,
    required this.posD,
    required this.neg,
    required this.negD,
    required this.neutral,
    required this.bg,
    required this.bgD,
    required this.text,
    required this.textD,
    required this.muted,
    required this.mutedD,
  });

  final String key, name;
  final Color ink, accent, accentD, pos, posD, neg, negD, neutral, bg, bgD, text, textD, muted, mutedD;
}

const palettes = <Palette>[
  Palette(key: 'terracotta', name: 'Terracotta', ink: Color(0xFF4A3333), accent: Color(0xFFE1473F), accentD: Color(0xFFEF6A61), pos: Color(0xFF3E7B75), posD: Color(0xFF8FC2BC), neg: Color(0xFFC63A33), negD: Color(0xFFF07A6F), neutral: Color(0xFFDBD1B3), bg: Color(0xFFF6F2EA), bgD: Color(0xFF161010), text: Color(0xFF2E2020), textD: Color(0xFFEFE8DC), muted: Color(0xFF6E5F5C), mutedD: Color(0xFFB3A49C)),
  Palette(key: 'midnight', name: 'Midnight', ink: Color(0xFF16233D), accent: Color(0xFF2F5BD3), accentD: Color(0xFF7096F5), pos: Color(0xFF157A62), posD: Color(0xFF5FCCA8), neg: Color(0xFFC2362D), negD: Color(0xFFF2867B), neutral: Color(0xFFC9D3E3), bg: Color(0xFFF3F5F9), bgD: Color(0xFF0C111B), text: Color(0xFF121A2B), textD: Color(0xFFE6EAF1), muted: Color(0xFF56627A), mutedD: Color(0xFF9AA6BB)),
  Palette(key: 'forest', name: 'Forest', ink: Color(0xFF1F3A30), accent: Color(0xFF2E7D5B), accentD: Color(0xFF5FBF8F), pos: Color(0xFF2A7A50), posD: Color(0xFF6FD1A0), neg: Color(0xFFB8432F), negD: Color(0xFFF08A72), neutral: Color(0xFFE3DCC4), bg: Color(0xFFF5F3EC), bgD: Color(0xFF0F1512), text: Color(0xFF18241F), textD: Color(0xFFE6ECE7), muted: Color(0xFF5D675F), mutedD: Color(0xFFA3AEA6)),
  Palette(key: 'graphite', name: 'Graphite', ink: Color(0xFF26282D), accent: Color(0xFFC94A17), accentD: Color(0xFFF07A45), pos: Color(0xFF2F7D62), posD: Color(0xFF6CC9A4), neg: Color(0xFFC0392B), negD: Color(0xFFF08577), neutral: Color(0xFFD8D4CC), bg: Color(0xFFF4F4F2), bgD: Color(0xFF111214), text: Color(0xFF18191C), textD: Color(0xFFECECEC), muted: Color(0xFF5F6168), mutedD: Color(0xFFA2A4AB)),
];

Palette paletteFor(String key) => palettes.firstWhere((p) => p.key == key, orElse: () => palettes.first);

const _t = Color(0x00000000);
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// CSS `color-mix(in srgb, a p%, b)`. Mixing with transparent keeps `a`'s
/// colour and scales its alpha, as the browser does.
Color mix(Color a, double p, Color b) {
  final f = p / 100;
  if (b.a == 0) return a.withValues(alpha: a.a * f);
  return Color.from(
    alpha: a.a * f + b.a * (1 - f),
    red: a.r * f + b.r * (1 - f),
    green: a.g * f + b.g * (1 - f),
    blue: a.b * f + b.b * (1 - f),
  );
}

/// CSS `oklch(L C h)` converted to sRGB.
Color oklch(double l, double c, double h) {
  final hr = h * math.pi / 180;
  final a = c * math.cos(hr), b = c * math.sin(hr);
  final l1 = math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m1 = math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s1 = math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  double g(double x) {
    final v = x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
    return v.clamp(0.0, 1.0);
  }

  return Color.from(
    alpha: 1,
    red: g(4.0767416621 * l1 - 3.3077115913 * m1 + 0.2309699292 * s1),
    green: g(-1.2684380046 * l1 + 2.6097574011 * m1 - 0.3413193965 * s1),
    blue: g(-0.0041960863 * l1 - 0.7034186147 * m1 + 1.7076147010 * s1),
  );
}

/// Resolved colour tokens for one palette in light or dark appearance.
/// Mirrors `buildTheme()` in the design prototype.
class LedgerColors {
  LedgerColors(this.palette, this.dark) {
    final c = palette;
    if (!dark) {
      emBg = c.ink;
      emBorder = _t;
      emShadow = mix(c.ink, 30, _t);
      emText = mix(c.neutral, 30, _white);
      emSub = c.neutral;
      emChip = mix(c.neutral, 60, _white);
      emDot = mix(c.neutral, 22, _t);
      emMark = mix(c.neutral, 8, _t);
      emLine = mix(c.neutral, 20, _t);
      emLineStrong = mix(c.neutral, 36, _t);
      emFlat = mix(c.neutral, 20, _t);
      emOnChip = c.ink;
      bg = c.bg;
      surface = mix(c.neutral, 35, c.bg);
      text = c.text;
      accent = c.accent;
      accent100 = mix(c.accent, 12, _white);
      accent600 = mix(c.accent, 82, _black);
      income = c.pos;
      expense = c.neg;
      card = mix(c.bg, 25, _white);
      line = mix(c.neutral, 40, _white);
      lineStrong = mix(c.neutral, 75, _white);
      muted = c.muted;
      segBg = mix(c.neutral, 40, c.bg);
      swOff = const Color.fromRGBO(120, 120, 128, .2);
      shadowLg = mix(c.ink, 18, _t);
      ic = [c.pos, c.ink, c.accent, mix(c.neutral, 60, _black), mix(c.pos, 80, _black), c.muted];
    } else {
      emBg = mix(c.ink, 75, _black);
      emBorder = mix(c.neutral, 18, _t);
      emShadow = const Color.fromRGBO(0, 0, 0, .45);
      emText = mix(c.neutral, 25, _white);
      emSub = mix(c.neutral, 85, _black);
      emChip = mix(c.neutral, 80, _white);
      emDot = mix(c.neutral, 15, _t);
      emMark = mix(c.neutral, 5, _t);
      emLine = mix(c.neutral, 14, _t);
      emLineStrong = mix(c.neutral, 28, _t);
      emFlat = mix(c.neutral, 14, _t);
      emOnChip = emBg;
      bg = c.bgD;
      surface = mix(c.bgD, 86, c.neutral);
      text = c.textD;
      accent = c.accentD;
      accent100 = mix(c.accentD, 18, c.bgD);
      accent600 = mix(c.accentD, 80, _white);
      income = c.posD;
      expense = c.negD;
      card = mix(c.bgD, 93, c.neutral);
      line = const Color.fromRGBO(255, 255, 255, .08);
      lineStrong = const Color.fromRGBO(255, 255, 255, .22);
      muted = c.mutedD;
      segBg = mix(c.bgD, 86, c.neutral);
      swOff = const Color.fromRGBO(150, 150, 160, .36);
      shadowLg = const Color.fromRGBO(0, 0, 0, .45);
      ic = [mix(c.posD, 80, _black), mix(c.ink, 70, c.neutral), c.accentD, mix(c.neutral, 55, _black), mix(c.posD, 60, _black), mix(c.mutedD, 70, _black)];
    }
    emUp = c.posD;
    emDown = c.negD;
    hero = c.ink;
  }

  final Palette palette;
  final bool dark;

  late final Color emBg, emBorder, emShadow, emText, emSub, emChip, emDot, emMark, emLine, emLineStrong, emUp, emDown, emFlat, emOnChip;
  late final Color bg, surface, text, accent, accent100, accent600, income, expense, card, line, lineStrong, muted, hero, segBg, swOff, shadowLg;

  /// Settings row icon tiles, `--ic1` … `--ic6`.
  late final List<Color> ic;

  static const backdrop = Color(0xFF05070B);

  List<BoxShadow> get shadowLgList => [BoxShadow(color: shadowLg, offset: const Offset(0, 12), blurRadius: 32)];

  /// Avatar tint and initials colour for a person, hashed from their name.
  ({Color tint, Color fg}) avatar(String name) {
    const hues = [25.0, 185.0, 75.0, 350.0, 160.0, 45.0];
    final h = hues[name.codeUnits.fold<int>(0, (a, c) => a + c) % hues.length];
    return dark ? (tint: oklch(0.32, 0.05, h), fg: oklch(0.86, 0.09, h)) : (tint: oklch(0.94, 0.035, h), fg: oklch(0.47, 0.12, h));
  }
}

class LedgerTheme extends InheritedWidget {
  const LedgerTheme({super.key, required this.colors, this.systemPalette, required super.child});

  final LedgerColors colors;

  /// The wallpaper palette, when this device has one to offer.
  final Palette? systemPalette;

  static LedgerColors of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LedgerTheme>()!.colors;

  static Palette? systemPaletteOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LedgerTheme>()!.systemPalette;

  @override
  bool updateShouldNotify(LedgerTheme old) => old.colors.palette != colors.palette || old.colors.dark != colors.dark || old.systemPalette != systemPalette;
}

extension LedgerContext on BuildContext {
  LedgerColors get c => LedgerTheme.of(this);
}

/// Archivo text style. [ls] is letter-spacing in em, as in the design.
TextStyle ts(double size, {int w = 400, Color? color, double ls = 0, double? height, bool tabular = false}) => TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      fontWeight: FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', w.toDouble())],
      color: color,
      letterSpacing: ls * size,
      height: height,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
