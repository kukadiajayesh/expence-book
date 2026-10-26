import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../models.dart';
import '../theme.dart';

/// Dot grid background: one dot centred in each [spacing]² tile. With
/// [fade], dots fade out along a 200° CSS linear gradient (opaque at the
/// top-right, gone by 65%).
class DotGridPainter extends CustomPainter {
  DotGridPainter({required this.color, required this.spacing, required this.radius, this.fade = false});

  final Color color;
  final double spacing, radius;
  final bool fade;

  @override
  void paint(Canvas canvas, Size size) {
    const a = 200 * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final len = (size.width * math.sin(a)).abs() + (size.height * math.cos(a)).abs();
    final centre = size.center(Offset.zero);
    final paint = Paint()..isAntiAlias = true;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        var alpha = 1.0;
        if (fade) {
          final p = Offset(x, y) - centre;
          final t = (p.dx * dir.dx + p.dy * dir.dy) / len + 0.5;
          alpha = (1 - t / 0.65).clamp(0.0, 1.0);
          if (alpha == 0) continue;
        }
        paint.color = color.withValues(alpha: color.a * alpha);
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) => old.color != color || old.spacing != spacing || old.fade != fade;
}

/// The "Net this month" money card on Overview (the 2b dot-grid concept).
class NetCard extends StatelessWidget {
  const NetCard({super.key, required this.got, required this.gave, required this.month});

  final double got, gave;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final net = got - gave;
    const white = Color(0xFFFFFFFF);

    Widget trend() {
      final (bg, fg, icon) = net > 0 ? (c.emUp, c.emOnChip, Ico.trendUp) : net < 0 ? (c.emDown, c.emOnChip, Ico.trendDown) : (c.emFlat, c.emText, Ico.flat);
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Ico(icon, size: 18, color: fg, stroke: 2.5),
      );
    }

    Widget figure(String label, String icon, Color iconColor, double v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Ico(icon, size: 14, color: iconColor, stroke: 2.75),
            const SizedBox(width: 6),
            Text(label, style: ts(12, w: 600, color: c.emSub)),
          ]),
          const SizedBox(height: 6),
          Text(fmt(v), style: ts(18, w: 700, color: white, tabular: true)),
        ]);

    return Container(
      decoration: BoxDecoration(
        color: c.emBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.emBorder),
        boxShadow: [BoxShadow(color: c.emShadow, offset: const Offset(0, 12), blurRadius: 26)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: DotGridPainter(color: c.emDot, spacing: 14, radius: 1.3, fade: true))),
        Positioned(
          right: -14,
          bottom: -62,
          child: Text('₹', style: ts(220, w: 800, color: c.emMark, height: 1)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Net this month', style: ts(13, w: 600, color: c.emSub))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: c.emLineStrong)),
                child: Row(children: [
                  Ico(Ico.calendar, size: 13, color: c.emChip, stroke: 2.5),
                  const SizedBox(width: 6),
                  Text(monthLabel(month), style: ts(12, w: 700, color: c.emChip)),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${net < 0 ? '−' : ''}${fmt(net)}', style: ts(42, w: 800, color: white, ls: -0.035, height: 1, tabular: true)),
                ),
              ),
              const SizedBox(width: 12),
              trend(),
            ]),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.emLine))),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: figure('Received', Ico.arrowIn, c.emUp, got)),
                  const SizedBox(width: 16),
                  Container(width: 1, color: c.emLine),
                  const SizedBox(width: 16),
                  Expanded(child: figure('Paid', Ico.arrowOut, c.emDown, gave)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
