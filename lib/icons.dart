import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Stroke icons from the design (24×24 viewBox), drawn with flutter_svg.
class Ico extends StatelessWidget {
  const Ico(this.paths, {super.key, required this.size, required this.color, this.stroke = 2});

  final String paths;
  final double size;
  final Color color;
  final double stroke;

  // Inner SVG markup for each icon used in the app.
  static const sun = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>';
  static const moon = '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>';
  static const plus = '<path d="M12 5v14"/><path d="M5 12h14"/>';
  static const calendar = '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18"/><path d="M8 3v4"/><path d="M16 3v4"/>';
  static const trendUp = '<path d="m3 17 6-6 4 4 8-8"/><path d="M14 7h7v7"/>';
  static const trendDown = '<path d="m3 7 6 6 4-4 8 8"/><path d="M14 17h7v-7"/>';
  static const flat = '<path d="M5 12h14"/>';
  static const arrowIn = '<path d="M17 7 7 17"/><path d="M17 17H7V7"/>';
  static const arrowOut = '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>';
  static const userPlus = '<circle cx="9" cy="8" r="4"/><path d="M3 21a6 6 0 0 1 12 0"/><path d="M19 8v6"/><path d="M16 11h6"/>';
  static const chevron = '<path d="m9 18 6-6-6-6"/>';
  static const search = '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>';
  static const sync = '<path d="M21 12a9 9 0 0 0-15-6.7L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 15 6.7l3-2.7"/><path d="M16 16h5v5"/>';
  static const close = '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>';
  static const notebook = '<path d="M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4"/><path d="M2 6h4"/><path d="M2 10h4"/><path d="M2 14h4"/><path d="M2 18h4"/><path d="M21.38 5.63a2.12 2.12 0 0 0-3-3l-7.39 7.4a2 2 0 0 0-.5.84l-.83 2.87a.5.5 0 0 0 .62.62l2.87-.84a2 2 0 0 0 .84-.5Z"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const check = '<path d="m5 12 5 5 9-10"/>';
  static const tick = '<path d="M20 6 9 17l-5-5"/>';
  static const bell = '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>';
  static const userAlert = '<circle cx="9" cy="8" r="4"/><path d="M3 21a6 6 0 0 1 12 0"/><path d="M19 8v5"/><path d="M19 17h.01"/>';
  static const lock = '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>';
  static const download = '<path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/>';
  static const tabOverview = '<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>';
  static const tabRecords = '<path d="M8 6h13"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M3 6h.01"/><path d="M3 12h.01"/><path d="M3 18h.01"/>';
  static const tabSettings = '<path d="M20 7h-9"/><path d="M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/>';

  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-opacity="${color.a}" '
        'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
