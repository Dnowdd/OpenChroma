import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';

/// The kinds of device OpenChroma draws its own artwork for.
enum DeviceKind {
  keyboard('Teclado'),
  mouse('Mouse'),
  headset('Headset'),
  mousepad('Mousepad'),
  motherboard('Placa-mãe'),
  gpu('Placa de vídeo'),
  ram('Memória'),
  fan('Ventoinhas'),
  cooler('Water cooler'),
  controller('Controladora'),
  strip('Fita de LED'),
  speakers('Caixas de som'),
  microphone('Microfone'),
  gamepad('Controle'),
  pcCase('Gabinete'),
  other('Dispositivo');

  const DeviceKind(this.label);
  final String label;
}

/// Picks the artwork from the plugin's device type, falling back to the
/// name for plugins that only say "other".
DeviceKind deviceKindOf(String type, String name) {
  final t = type.toLowerCase();
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  final byType = switch (t) {
    'keyboard' || 'keypad' => DeviceKind.keyboard,
    'mouse' => DeviceKind.mouse,
    'headphones' || 'headset' => DeviceKind.headset,
    'mousepad' => DeviceKind.mousepad,
    'motherboard' => DeviceKind.motherboard,
    'gpu' => DeviceKind.gpu,
    'ram' => DeviceKind.ram,
    'fan' || 'fans' => DeviceKind.fan,
    'aio' || 'cooler' => DeviceKind.cooler,
    'ledstrip' || 'light' => DeviceKind.strip,
    'gamepad' => DeviceKind.gamepad,
    'lightingcontroller' => DeviceKind.controller,
    'speakers' => DeviceKind.speakers,
    'microphone' => DeviceKind.microphone,
    'case' => DeviceKind.pcCase,
    _ => null,
  };
  if (byType != null) return byType;
  if (has([
    'dualshock',
    'dualsense',
    'controller for',
    'gamepad',
    'joystick',
  ])) {
    return DeviceKind.gamepad;
  }
  if (has(['keyboard', 'teclado', 'keypad'])) return DeviceKind.keyboard;
  if (has(['mouse'])) return DeviceKind.mouse;
  if (has(['headset', 'headphone', 'earbud'])) return DeviceKind.headset;
  if (has(['mousepad', 'mouse pad', 'mat'])) return DeviceKind.mousepad;
  if (has(['strip', 'fita', 'light bar', 'lightbar'])) return DeviceKind.strip;
  if (has(['fan', 'cooler'])) return DeviceKind.fan;
  if (has(['aio', 'kraken', 'pump'])) return DeviceKind.cooler;
  if (has(['ram', 'dimm', 'dram'])) return DeviceKind.ram;
  if (has(['speaker'])) return DeviceKind.speakers;
  if (has(['mic'])) return DeviceKind.microphone;
  if (has(['controller', 'hub', 'argb'])) return DeviceKind.controller;
  return DeviceKind.other;
}

/// A device drawn in OpenChroma's own style, its LEDs lit with the colors
/// the device is getting right now.
class DeviceArt extends StatefulWidget {
  const DeviceArt({
    super.key,
    required this.engine,
    required this.device,
    this.size = 40,
    this.framed = true,
  });
  final Engine engine;
  final DeviceInstance device;
  final double size;

  /// Draws the rounded tile behind the artwork.
  final bool framed;

  @override
  State<DeviceArt> createState() => _DeviceArtState();
}

class _DeviceArtState extends State<DeviceArt> {
  final _repaint = ValueNotifier<int>(0);
  List<Color> _colors = const [];
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    widget.engine.frameNotifier.addListener(_onFrame);
    _onFrame();
  }

  @override
  void didUpdateWidget(DeviceArt old) {
    super.didUpdateWidget(old);
    if (old.engine != widget.engine) {
      old.engine.frameNotifier.removeListener(_onFrame);
      widget.engine.frameNotifier.addListener(_onFrame);
    }
  }

  @override
  void dispose() {
    widget.engine.frameNotifier.removeListener(_onFrame);
    _repaint.dispose();
    super.dispose();
  }

  void _onFrame() {
    // A thumbnail needs no more than ~10 updates a second.
    if (_frames++ % 3 != 0) return;
    _colors = widget.engine.previewColors(widget.device, 12);
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final kind = deviceKindOf(d.type, d.name);
    final s = widget.size;
    final art = CustomPaint(
      size: Size.square(s),
      painter: DevicePainter(
        kind: kind,
        colors: () => _colors,
        repaint: _repaint,
      ),
    );
    if (!widget.framed) return SizedBox.square(dimension: s, child: art);
    return Container(
      width: s,
      height: s,
      padding: EdgeInsets.all(s * .1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24242A), Color(0xFF17171B)],
        ),
        borderRadius: BorderRadius.circular(s * .28),
        border: Border.all(color: Oc.line),
      ),
      child: art,
    );
  }
}

/// Draws a [DeviceKind] in a square: a graphite body with hairline edges and
/// glowing LED areas. [colors] are the live LED colors, left to right; when
/// empty the LEDs show a dim neutral.
class DevicePainter extends CustomPainter {
  DevicePainter({required this.kind, required this.colors, super.repaint});
  final DeviceKind kind;
  final List<Color> Function() colors;

  late double _u;
  late Canvas _c;
  late List<Color> _live;

  static const _body = Color(0xFF2E2E35);
  static const _bodyLight = Color(0xFF3A3A42);
  static const _edge = Color(0xFF4A4A54);
  static const _detail = Color(0xFF1C1C21);
  static const _idle = Color(0xFF55555F);

  Color _led(double t) {
    if (_live.isEmpty) return _idle;
    final x = (t.clamp(0.0, 1.0)) * (_live.length - 1);
    final i = x.floor().clamp(0, _live.length - 1);
    final j = math.min(i + 1, _live.length - 1);
    final c = Color.lerp(_live[i], _live[j], x - i)!;
    // Keep LEDs visible on a dark body even when the effect is dim.
    final hsv = HSVColor.fromColor(c);
    return hsv.value < .25 ? _idle : c;
  }

  Offset _p(double x, double y) => Offset(x * _u, y * _u);
  Rect _r(double l, double t, double w, double h) =>
      Rect.fromLTWH(l * _u, t * _u, w * _u, h * _u);
  RRect _rr(double l, double t, double w, double h, double r) =>
      RRect.fromRectAndRadius(_r(l, t, w, h), Radius.circular(r * _u));

  void _shape(RRect r, {Color color = _body}) {
    _c.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, .06)!, color],
        ).createShader(r.outerRect),
    );
    _c.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, _u * .012)
        ..color = _edge,
    );
  }

  void _path(Path p, {Color color = _body}) {
    _c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, .06)!, color],
        ).createShader(p.getBounds()),
    );
    _c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, _u * .012)
        ..color = _edge,
    );
  }

  /// A lit shape with a soft glow around it.
  void _glowRRect(RRect r, Color c, {double glow = .05}) {
    if (c != _idle) {
      _c.drawRRect(
        r,
        Paint()
          ..color = c.withValues(alpha: .55)
          ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, glow * _u),
      );
    }
    _c.drawRRect(r, Paint()..color = c);
  }

  void _glowCircleStroke(
    Offset o,
    double radius,
    double width,
    Color Function(double) at,
  ) {
    const n = 24;
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 2 * math.pi - math.pi / 2;
      final c = at(i / n);
      final rect = Rect.fromCircle(center: o, radius: radius);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = c;
      if (c != _idle) {
        _c.drawArc(
          rect,
          a0,
          2 * math.pi / n + .02,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 1.8
            ..color = c.withValues(alpha: .35)
            ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, width),
        );
      }
      _c.drawArc(rect, a0, 2 * math.pi / n + .02, false, p);
    }
  }

  void _fan(Offset o, double r, {double t0 = 0, double t1 = 1}) {
    _c.drawCircle(o, r, Paint()..color = _detail);
    _glowCircleStroke(o, r * .9, r * .13, (t) => _led(t0 + (t1 - t0) * t));
    final blade = Paint()..color = _bodyLight;
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * 2 * math.pi;
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..quadraticBezierTo(
          o.dx + math.cos(a) * r * .9,
          o.dy + math.sin(a) * r * .9,
          o.dx + math.cos(a + .55) * r * .72,
          o.dy + math.sin(a + .55) * r * .72,
        )
        ..close();
      _c.drawPath(p, blade);
    }
    _c.drawCircle(o, r * .24, Paint()..color = _body);
    _c.drawCircle(
      o,
      r * .24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, _u * .01)
        ..color = _edge,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    _u = size.shortestSide;
    _live = colors();
    switch (kind) {
      case DeviceKind.keyboard:
        _keyboard();
      case DeviceKind.mouse:
        _mouse();
      case DeviceKind.headset:
        _headset();
      case DeviceKind.mousepad:
        _mousepad();
      case DeviceKind.motherboard:
        _motherboard();
      case DeviceKind.gpu:
        _gpu();
      case DeviceKind.ram:
        _ram();
      case DeviceKind.fan:
        _fan(_p(.5, .5), .42 * _u);
      case DeviceKind.cooler:
        _cooler();
      case DeviceKind.controller:
        _controller();
      case DeviceKind.strip:
        _strip();
      case DeviceKind.speakers:
        _speakers();
      case DeviceKind.microphone:
        _microphone();
      case DeviceKind.gamepad:
        _gamepad();
      case DeviceKind.pcCase:
        _case();
      case DeviceKind.other:
        _chip();
    }
  }

  void _keyboard() {
    // Underglow first, then the board on top.
    _glowRRect(_rr(.06, .70, .88, .03, .015), _led(.5), glow: .06);
    _shape(_rr(.03, .30, .94, .40, .05));
    const rows = 5, cols = 14;
    const kw = .88 / cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // A wide space bar on the last row.
        if (r == rows - 1 && c > 3 && c < 10) {
          if (c == 4) {
            _glowRRect(
              _rr(.06 + c * kw, .335 + r * .068, kw * 6 - .01, .055, .012),
              _led((c + 3) / cols),
              glow: .02,
            );
          }
          continue;
        }
        _glowRRect(
          _rr(.06 + c * kw, .335 + r * .068, kw - .01, .055, .012),
          _led(c / (cols - 1)),
          glow: .02,
        );
      }
    }
  }

  void _mouse() {
    final body = _rr(.29, .1, .42, .8, .21);
    _glowRRect(_rr(.27, .74, .46, .14, .07), _led(.5), glow: .07);
    _shape(body);
    // Button split and wheel.
    _c.drawLine(
      _p(.5, .12),
      _p(.5, .42),
      Paint()
        ..color = _detail
        ..strokeWidth = math.max(1, _u * .014),
    );
    _c.drawLine(
      _p(.31, .42),
      _p(.69, .42),
      Paint()
        ..color = _detail
        ..strokeWidth = math.max(1, _u * .01),
    );
    _glowRRect(_rr(.465, .18, .07, .14, .035), _led(.2), glow: .03);
    // Logo.
    _glowRRect(_rr(.44, .58, .12, .12, .06), _led(.8), glow: .05);
  }

  void _headset() {
    final band = Path()
      ..moveTo(.2 * _u, .55 * _u)
      ..cubicTo(.2 * _u, .05 * _u, .8 * _u, .05 * _u, .8 * _u, .55 * _u);
    _c.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .07 * _u
        ..strokeCap = StrokeCap.round
        ..color = _body,
    );
    _c.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .012 * _u
        ..color = _edge,
    );
    for (final (x, t) in [(.1, .2), (.66, .8)]) {
      _shape(_rr(x, .45, .24, .38, .11));
      _glowRRect(_rr(x + .05, .54, .14, .2, .07), _led(t), glow: .05);
    }
  }

  void _mousepad() {
    final pad = _rr(.04, .24, .92, .52, .06);
    _glowRRect(pad, _led(.5), glow: .06);
    // The lit edge follows the colors along its length.
    const n = 20;
    for (var i = 0; i < n; i++) {
      _glowRRect(
        _rr(.04 + i * .92 / n, .24, .92 / n + .003, .52, 0),
        _led(i / (n - 1)),
        glow: 0,
      );
    }
    _shape(_rr(.07, .275, .86, .45, .045), color: const Color(0xFF232328));
  }

  void _motherboard() {
    _shape(_rr(.1, .06, .8, .88, .04), color: const Color(0xFF26262C));
    // CPU socket, RAM slots, PCIe slots.
    _shape(_rr(.22, .16, .26, .26, .02), color: _bodyLight);
    for (var i = 0; i < 4; i++) {
      _shape(_rr(.58 + i * .07, .14, .035, .34, .01), color: _detail);
    }
    for (var i = 0; i < 2; i++) {
      _shape(_rr(.18, .58 + i * .14, .56, .04, .01), color: _detail);
    }
    // Lit armour strip along the edge.
    for (var i = 0; i < 6; i++) {
      _glowRRect(
        _rr(.16 + i * .1, .5, .085, .025, .01),
        _led(i / 5),
        glow: .03,
      );
    }
    _glowRRect(_rr(.82, .14, .03, .7, .015), _led(.9), glow: .04);
  }

  void _gpu() {
    _shape(_rr(.03, .28, .94, .44, .05));
    _shape(_rr(.03, .7, .2, .06, .01), color: _detail);
    _fan(_p(.29, .5), .17 * _u, t0: 0, t1: .45);
    _fan(_p(.71, .5), .17 * _u, t0: .55, t1: 1);
    _glowRRect(_rr(.1, .26, .8, .025, .012), _led(.5), glow: .04);
  }

  void _ram() {
    for (final (x, t) in [(.26, .25), (.54, .75)]) {
      _shape(_rr(x, .2, .2, .7, .02), color: const Color(0xFF26262C));
      _glowRRect(_rr(x + .01, .1, .18, .12, .03), _led(t), glow: .06);
      for (var i = 0; i < 4; i++) {
        _shape(_rr(x + .04, .34 + i * .13, .12, .09, .01), color: _detail);
      }
    }
  }

  void _cooler() {
    // Radiator with two fans, tubes and the pump head.
    _shape(_rr(.05, .08, .9, .36, .04));
    _fan(_p(.29, .26), .14 * _u, t0: 0, t1: .4);
    _fan(_p(.71, .26), .14 * _u, t0: .4, t1: .8);
    final tube = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .045 * _u
      ..strokeCap = StrokeCap.round
      ..color = _body;
    _c.drawPath(
      Path()
        ..moveTo(.42 * _u, .44 * _u)
        ..quadraticBezierTo(.38 * _u, .6 * _u, .45 * _u, .66 * _u),
      tube,
    );
    _c.drawPath(
      Path()
        ..moveTo(.58 * _u, .44 * _u)
        ..quadraticBezierTo(.62 * _u, .6 * _u, .55 * _u, .66 * _u),
      tube,
    );
    _c.drawCircle(_p(.5, .78), .15 * _u, Paint()..color = _body);
    _glowCircleStroke(
      _p(.5, .78),
      .13 * _u,
      .03 * _u,
      (t) => _led(.8 + t * .2),
    );
    _c.drawCircle(_p(.5, .78), .08 * _u, Paint()..color = _detail);
  }

  void _controller() {
    _shape(_rr(.3, .3, .4, .4, .06));
    _glowRRect(_rr(.36, .36, .28, .05, .02), _led(.5), glow: .04);
    // Cables out to LED strips.
    for (var i = 0; i < 3; i++) {
      final y = .44 + i * .08;
      _c.drawLine(
        _p(.7, y),
        _p(.92, y),
        Paint()
          ..color = _bodyLight
          ..strokeWidth = .02 * _u,
      );
      _glowRRect(_rr(.88, y - .02, .06, .04, .02), _led(i / 2), glow: .03);
      _c.drawLine(
        _p(.08, y),
        _p(.3, y),
        Paint()
          ..color = _bodyLight
          ..strokeWidth = .02 * _u,
      );
    }
  }

  void _strip() {
    final path = Path()
      ..moveTo(.06 * _u, .7 * _u)
      ..cubicTo(.3 * _u, .1 * _u, .7 * _u, .9 * _u, .94 * _u, .3 * _u);
    _c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .09 * _u
        ..strokeCap = StrokeCap.round
        ..color = _body,
    );
    final metric = path.computeMetrics().first;
    const n = 12;
    for (var i = 0; i < n; i++) {
      final pos = metric
          .getTangentForOffset(metric.length * (i + .5) / n)!
          .position;
      final c = _led(i / (n - 1));
      if (c != _idle) {
        _c.drawCircle(
          pos,
          .05 * _u,
          Paint()
            ..color = c.withValues(alpha: .5)
            ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, .03 * _u),
        );
      }
      _c.drawCircle(pos, .025 * _u, Paint()..color = c);
    }
  }

  void _speakers() {
    for (final (x, t) in [(.08, .2), (.56, .8)]) {
      _shape(_rr(x, .2, .36, .64, .05));
      _c.drawCircle(_p(x + .18, .36), .07 * _u, Paint()..color = _detail);
      _c.drawCircle(_p(x + .18, .62), .12 * _u, Paint()..color = _detail);
      _glowCircleStroke(_p(x + .18, .62), .13 * _u, .02 * _u, (_) => _led(t));
    }
  }

  void _microphone() {
    _shape(_rr(.36, .08, .28, .5, .14));
    for (var i = 0; i < 4; i++) {
      _c.drawLine(
        _p(.4, .16 + i * .08),
        _p(.6, .16 + i * .08),
        Paint()
          ..color = _detail
          ..strokeWidth = math.max(1, .012 * _u),
      );
    }
    _glowRRect(_rr(.38, .5, .24, .05, .025), _led(.5), glow: .05);
    _shape(_rr(.47, .58, .06, .22, .02));
    _shape(_rr(.28, .8, .44, .08, .04));
  }

  void _gamepad() {
    final p = Path()
      ..moveTo(.2 * _u, .32 * _u)
      ..lineTo(.8 * _u, .32 * _u)
      ..cubicTo(.95 * _u, .32 * _u, 1 * _u, .8 * _u, .88 * _u, .82 * _u)
      ..cubicTo(.8 * _u, .84 * _u, .72 * _u, .62 * _u, .64 * _u, .62 * _u)
      ..lineTo(.36 * _u, .62 * _u)
      ..cubicTo(.28 * _u, .62 * _u, .2 * _u, .84 * _u, .12 * _u, .82 * _u)
      ..cubicTo(0, .8 * _u, .05 * _u, .32 * _u, .2 * _u, .32 * _u)
      ..close();
    // The light bar sits on top.
    _glowRRect(_rr(.32, .27, .36, .05, .025), _led(.5), glow: .06);
    _path(p);
    _c.drawCircle(_p(.36, .52), .055 * _u, Paint()..color = _detail);
    _c.drawCircle(_p(.64, .52), .055 * _u, Paint()..color = _detail);
    for (final (dx, dy) in [(0.0, -.06), (.06, 0.0), (0.0, .06), (-.06, 0.0)]) {
      _c.drawCircle(
        _p(.78 + dx, .44 + dy),
        .025 * _u,
        Paint()..color = _detail,
      );
      _c.drawRRect(
        _rr(.2 + dx - .02, .44 + dy - .02, .04, .04, .008),
        Paint()..color = _detail,
      );
    }
  }

  void _case() {
    _shape(_rr(.22, .06, .56, .88, .04));
    _shape(_rr(.27, .11, .46, .78, .03), color: const Color(0xFF1F1F24));
    for (var i = 0; i < 3; i++) {
      _fan(_p(.5, .24 + i * .26), .11 * _u, t0: i / 3, t1: (i + 1) / 3);
    }
  }

  void _chip() {
    _shape(_rr(.24, .24, .52, .52, .06));
    final pin = Paint()
      ..color = _edge
      ..strokeWidth = .025 * _u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final k = .32 + i * .12;
      _c.drawLine(_p(k, .12), _p(k, .22), pin);
      _c.drawLine(_p(k, .78), _p(k, .88), pin);
      _c.drawLine(_p(.12, k), _p(.22, k), pin);
      _c.drawLine(_p(.78, k), _p(.88, k), pin);
    }
    _glowRRect(_rr(.38, .38, .24, .24, .05), _led(.5), glow: .06);
  }

  @override
  bool shouldRepaint(DevicePainter old) => old.kind != kind;
}
