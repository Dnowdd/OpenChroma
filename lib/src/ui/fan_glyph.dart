import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// A PC case fan seen from the front: square frame with screw holes, a
/// shroud, nine swept blades in [color] and a hub. Spins at [speed] turns
/// per second and blurs its blades when fast.
class FanGlyph extends StatefulWidget {
  const FanGlyph({
    super.key,
    required this.color,
    this.size = 96,
    this.speed = .5,
  });
  final Color color;
  final double size;
  final double speed;

  @override
  State<FanGlyph> createState() => _FanGlyphState();
}

class _FanGlyphState extends State<FanGlyph>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final _angle = ValueNotifier<double>(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Integrate the angle so speed changes don't make the blades jump.
    _spin.addListener(() {
      final now = _spin.lastElapsedDuration ?? Duration.zero;
      final dt = (now - _last).inMicroseconds / 1e6;
      _last = now;
      if (dt > 0 && dt < .2) _angle.value += dt * widget.speed;
    });
    _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    _angle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _FanPainter(_angle, widget.color, widget.speed),
      ),
    ),
  );
}

class _FanPainter extends CustomPainter {
  _FanPainter(this.turns, this.color, this.speed) : super(repaint: turns);
  final ValueNotifier<double> turns;
  final Color color;
  final double speed;

  static const _blades = 9;

  Offset _polar(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);

  Path _blade(double s) {
    final hub = s * .135;
    final tip = s * .425;
    const rootWidth = .36;
    const sweep = .62;
    const tipWidth = .40;
    final path = Path()..moveTo(_polar(hub, 0).dx, _polar(hub, 0).dy);
    final lead = _polar(tip, sweep);
    final leadCtrl = _polar(hub + (tip - hub) * .62, sweep * .22);
    path.quadraticBezierTo(leadCtrl.dx, leadCtrl.dy, lead.dx, lead.dy);
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: tip),
      sweep,
      tipWidth,
      false,
    );
    final rootEnd = _polar(hub, rootWidth);
    final trailCtrl = _polar(hub + (tip - hub) * .5, rootWidth + sweep * .62);
    path.quadraticBezierTo(trailCtrl.dx, trailCtrl.dy, rootEnd.dx, rootEnd.dy);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: s, height: s),
      Radius.circular(s * .16),
    );

    // Frame.
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF26262B), Color(0xFF1A1A1E)],
        ).createShader(frame.outerRect),
    );
    canvas.drawRRect(
      frame.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Oc.lineStrong,
    );
    for (final dx in [-1, 1]) {
      for (final dy in [-1, 1]) {
        final p = c + Offset(dx * s * .39, dy * s * .39);
        canvas.drawCircle(p, s * .032, Paint()..color = Oc.bg);
        canvas.drawCircle(
          p,
          s * .032,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Oc.lineStrong,
        );
      }
    }

    // Shroud, with a faint glow of the blades' color.
    final shroud = s * .455;
    canvas.drawCircle(c, shroud, Paint()..color = const Color(0xFF0E0E11));
    canvas.drawCircle(
      c,
      shroud,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .16), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: shroud)),
    );
    canvas.drawCircle(
      c,
      shroud,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Oc.line,
    );

    // Blades, with trailing ghosts for motion blur at speed.
    final blade = _blade(s);
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, .25)!,
          color,
          Color.lerp(color, Colors.black, .25)!,
        ],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * .43));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, s * .006)
      ..color = Colors.black.withValues(alpha: .35);
    final blur = (speed / 2).clamp(0.0, 1.0);
    final angle = turns.value * 2 * math.pi;

    void drawBlades(double offset, double alpha, {bool edges = true}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle + offset);
      for (var i = 0; i < _blades; i++) {
        if (alpha < 1) {
          canvas.drawPath(
            blade,
            Paint()..color = color.withValues(alpha: alpha),
          );
        } else {
          canvas.drawPath(blade, fill);
          if (edges) canvas.drawPath(blade, edge);
        }
        canvas.rotate(2 * math.pi / _blades);
      }
      canvas.restore();
    }

    if (blur > .05) {
      drawBlades(-.22 * blur, .10 * blur);
      drawBlades(-.11 * blur, .18 * blur);
    }
    drawBlades(0, 1);

    // Hub.
    final hub = s * .145;
    canvas.drawCircle(
      c,
      hub,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34343A), Color(0xFF1C1C20)],
        ).createShader(Rect.fromCircle(center: c, radius: hub)),
    );
    canvas.drawCircle(
      c,
      hub * .62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * .012)
        ..color = color.withValues(alpha: .8),
    );
    canvas.drawCircle(c, hub * .22, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.color != color || old.speed != speed;
}
