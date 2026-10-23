import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Spring feel from the design's Tweaks panel: 0.42 s response, 0.86 damping.
const springResponse = 0.42;
const springDamping = 0.86;

/// Drives one sheet's vertical offset (0 = fully open, [closed] = off screen)
/// with a damped spring. Any animation can be grabbed and redirected.
class SheetController extends ChangeNotifier {
  SheetController({required TickerProvider vsync, required this.maxOpacity, this.onClosed}) : _anim = AnimationController.unbounded(vsync: vsync, value: 10000) {
    _anim.addListener(notifyListeners);
  }

  final AnimationController _anim;
  final double maxOpacity;
  final VoidCallback? onClosed;

  List<double> detents = const [0];
  double closed = 10000;
  bool reduceMotion = false;

  double get y => _anim.value;
  double get velocity => _anim.velocity;
  bool get isOpen => y < closed - 0.5;
  bool get isAnimating => _anim.isAnimating;
  double get progress => ((closed - y) / closed).clamp(0.0, 1.0);

  /// Called during layout with the current screen geometry.
  void setGeometry(List<double> detents, double closed) {
    this.detents = detents;
    final wasClosed = !isOpen && !isAnimating;
    this.closed = closed;
    if (wasClosed) _anim.value = closed;
  }

  SpringDescription get _spring {
    final resp = reduceMotion ? 0.25 : springResponse, zeta = reduceMotion ? 1.0 : springDamping;
    return SpringDescription(mass: 1, stiffness: math.pow(2 * math.pi / resp, 2).toDouble(), damping: 4 * math.pi * zeta / resp);
  }

  void animateTo(double target, [double velocity = 0]) {
    _anim.animateWith(SpringSimulation(_spring, y, target, velocity, tolerance: const Tolerance(distance: .5, velocity: 4))).then((_) {
      if (target == closed) onClosed?.call();
    });
  }

  void open([int detent = 0]) => animateTo(detents[detent]);
  void close() => animateTo(closed);
  void stop() => _anim.stop();
  void jump(double v) => _anim.value = v;

  List<double> get stops => [...detents, closed];
  double nearest(double v) => stops.reduce((a, b) => (b - v).abs() < (a - v).abs() ? b : a);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}

/// Scroll physics for content inside a sheet: the sheet's pointer handler
/// moves the scroll position itself, so the Scrollable must not take drags.
class SheetScrollPhysics extends ClampingScrollPhysics {
  const SheetScrollPhysics({super.parent});

  @override
  SheetScrollPhysics applyTo(ScrollPhysics? ancestor) => SheetScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;
}

/// Makes its whole subtree a drag handle for [controller]. When the pointer
/// starts inside [scrollKey]'s viewport, vertical moves scroll the content
/// first and hand off to the sheet at the top edge, like UISheetPresentation.
class SheetDragArea extends StatefulWidget {
  const SheetDragArea({super.key, required this.controller, required this.child, this.scroll, this.scrollKey});

  final SheetController controller;
  final ScrollController? scroll;
  final GlobalKey? scrollKey;
  final Widget child;

  @override
  State<SheetDragArea> createState() => SheetDragAreaState();
}

/// Wrap text fields in this so pressing in them never drags the sheet.
class NoSheetDrag extends StatelessWidget {
  const NoSheetDrag({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => context.findAncestorStateOfType<SheetDragAreaState>()?._ignored = e.pointer,
      child: child,
    );
  }
}

class _Drag {
  _Drag(this.pointer, this.py, this.startY, this.inScroll, this.startScroll);

  final int pointer;
  double py, startY, startScroll;
  final bool inScroll;
  String? mode; // null until the pointer moves 4px; then 'scroll' or 'sheet'
  final samples = <(Duration, double)>[];
}

class SheetDragAreaState extends State<SheetDragArea> {
  _Drag? _d;
  int? _ignored;
  double _grabVelocity = 0;
  final _clock = Stopwatch()..start();

  SheetController get _c => widget.controller;

  bool _hitsScroll(Offset global) {
    final box = widget.scrollKey?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  void _down(PointerDownEvent e) {
    if (_d != null || _ignored == e.pointer || (e.buttons & kPrimaryButton) == 0) return;
    _grabVelocity = _c.isAnimating ? _c.velocity : 0;
    _c.stop();
    final sc = widget.scroll;
    _d = _Drag(e.pointer, e.position.dy, _c.y, sc != null && sc.hasClients && _hitsScroll(e.position), sc != null && sc.hasClients ? sc.offset : 0)
      ..samples.add((_clock.elapsed, e.position.dy));
  }

  void _move(PointerMoveEvent e) {
    final d = _d;
    if (d == null || d.pointer != e.pointer) return;
    final top = _c.detents.first, sc = widget.scroll;
    final dy = e.position.dy;
    if (d.mode == null) {
      if ((dy - d.py).abs() < 4) return;
      final atTop = (_c.y - top).abs() < 2;
      final canScroll = d.inScroll && atTop && sc!.position.maxScrollExtent > 1;
      d.mode = canScroll && (dy < d.py || sc.offset > 0) ? 'scroll' : 'sheet';
      d.py = dy;
      d.startY = _c.y;
      d.startScroll = sc != null && sc.hasClients ? sc.offset : 0;
    }
    final now = _clock.elapsed;
    d.samples.add((now, dy));
    while (d.samples.length > 2 && (now - d.samples.first.$1).inMilliseconds > 90) {
      d.samples.removeAt(0);
    }
    if (d.mode == 'scroll') {
      final want = d.startScroll - (dy - d.py);
      if (want >= 0) {
        sc!.jumpTo(math.min(want, sc.position.maxScrollExtent));
        return;
      }
      sc!.jumpTo(0);
      d.mode = 'sheet';
      d.py = dy;
      d.startY = _c.y;
    }
    final raw = d.startY + (dy - d.py);
    _c.jump(raw < top ? top - _rubber(top - raw) : raw);
  }

  double _rubber(double x) {
    final h = MediaQuery.sizeOf(context).height;
    return (1 - 1 / (x * 0.55 / h + 1)) * h;
  }

  double _releaseVelocity(_Drag d) {
    final a = d.samples.first, b = d.samples.last;
    final dt = (b.$1 - a.$1).inMicroseconds / 1e6;
    final fresh = (_clock.elapsed - b.$1).inMilliseconds < 80;
    return dt > 0 && fresh ? (b.$2 - a.$2) / dt : 0;
  }

  void _up(PointerEvent e) {
    if (_ignored == e.pointer) _ignored = null;
    final d = _d;
    if (d == null || d.pointer != e.pointer) return;
    _d = null;
    if (d.mode == 'scroll') {
      final sc = widget.scroll!;
      final v = _releaseVelocity(d);
      if (sc.position is ScrollPositionWithSingleContext) (sc.position as ScrollPositionWithSingleContext).goBallistic(-v);
      return;
    }
    if (d.mode == null) {
      // A tap that caught the sheet mid-flight: let it carry on to rest.
      final n = _c.nearest(_c.y);
      if ((n - _c.y).abs() > .5) _c.animateTo(n, _grabVelocity);
      return;
    }
    final v = _releaseVelocity(d);
    final projected = _c.y + v * 0.998 / (1 - 0.998) / 1000;
    _c.animateTo(_c.nearest(projected), v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerDown: _down, onPointerMove: _move, onPointerUp: _up, onPointerCancel: _up, child: widget.child);
  }
}

/// Backdrop + sheet pair. The sheet slides by the controller's offset and is
/// taken offstage when fully closed.
class SheetLayer extends StatelessWidget {
  const SheetLayer({super.key, required this.controller, required this.onDismiss, required this.sheet, this.left = 0, this.right = 0, this.bottom = 0, this.height});

  final SheetController controller;
  final VoidCallback onDismiss;
  final Widget sheet;
  final double left, right, bottom;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final open = controller.isOpen;
        return Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !open,
              child: GestureDetector(
                onTap: onDismiss,
                child: ColoredBox(color: LedgerColors.backdrop.withValues(alpha: controller.maxOpacity * controller.progress)),
              ),
            ),
          ),
          Positioned(
            left: left,
            right: right,
            bottom: bottom,
            height: height,
            child: Offstage(
              offstage: !open,
              child: Transform.translate(offset: Offset(0, controller.y), child: child),
            ),
          ),
        ]);
      },
      child: sheet,
    );
  }
}

/// The 36×5 grabber pill at the top of a sheet.
class Grabber extends StatelessWidget {
  const Grabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          width: 36,
          height: 5,
          decoration: BoxDecoration(color: context.c.lineStrong, borderRadius: BorderRadius.circular(999)),
        ),
      );
}
