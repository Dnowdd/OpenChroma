import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../monitor/system_monitor.dart';
import 'accent.dart';
import 'fan_glyph.dart';
import 'theme.dart';
import 'widgets.dart';

/// Fan control. Visual preview for now: the hardware side (motherboard
/// Super I/O through PawnIO, AIO pumps over HID) comes later. Temperatures
/// are real.
class FansPage extends StatefulWidget {
  const FansPage({super.key, required this.monitor, required this.active});
  final SystemMonitor monitor;
  final bool active;

  @override
  State<FansPage> createState() => _FansPageState();
}

/// A fan curve: (temperature °C, speed %) points.
typedef _Curve = List<(double, double)>;

class _FansPageState extends State<FansPage> {
  int _mode = 1;
  bool _gpu = false;
  bool _zeroRpm = true;

  static const _modes = ['Silencioso', 'Equilibrado', 'Turbo'];
  static const _curves = <_Curve>[
    [(20, 20), (50, 25), (70, 45), (85, 75), (100, 100)],
    [(20, 30), (50, 40), (70, 65), (85, 90), (100, 100)],
    [(20, 50), (50, 65), (70, 85), (85, 100), (100, 100)],
  ];
  static const _fans = ['CPU', 'Frente 1', 'Frente 2', 'Frente 3', 'Traseira'];

  @override
  void initState() {
    super.initState();
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void didUpdateWidget(FansPage old) {
    super.didUpdateWidget(old);
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void dispose() {
    widget.monitor.setActive(this, false);
    super.dispose();
  }

  static double _speedAt(_Curve curve, double t) {
    if (t <= curve.first.$1) return curve.first.$2;
    for (var i = 1; i < curve.length; i++) {
      final (t1, s1) = curve[i];
      final (t0, s0) = curve[i - 1];
      if (t <= t1) return s0 + (s1 - s0) * (t - t0) / (t1 - t0);
    }
    return curve.last.$2;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.monitor,
    builder: (context, _) {
      final s = widget.monitor.snapshot;
      final cpuTemp = s?.cpu.temp;
      final gpuTemp = s?.gpus.firstOrNull?.temp;
      // Without the CPU sensor (no admin), follow the GPU.
      final useGpu = _gpu || cpuTemp == null;
      final temp = useGpu ? gpuTemp : cpuTemp;
      final curve = _curves[_mode];
      final speed = temp == null ? null : _speedAt(curve, temp);
      final spin = .15 + (speed ?? 40) / 100 * 1.6;
      return LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1100;
          final curveCard = _CurveCard(
            curve: curve,
            temp: temp,
            speed: speed,
            source: useGpu ? 'GPU' : 'CPU',
            gpu: useGpu,
            cpuAvailable: cpuTemp != null,
            onSource: (v) => setState(() => _gpu = v),
          );
          final now = _NowCard(
            speed: speed,
            spin: spin,
            mode: _modes[_mode],
            zeroRpm: _zeroRpm,
            onZeroRpm: (v) => setState(() => _zeroRpm = v),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 22),
                        child: Row(
                          children: [
                            Text(
                              'Ventoinhas',
                              style: OcText.pageTitle.copyWith(fontSize: 28),
                            ),
                            const SizedBox(width: 12),
                            const OcTag('Prévia'),
                            const Spacer(),
                            OcSegmented<int>(
                              value: _mode,
                              options: [
                                for (var i = 0; i < _modes.length; i++)
                                  (i, _modes[i]),
                              ],
                              onChanged: (v) => setState(() => _mode = v),
                            ),
                          ],
                        ),
                      ),
                      if (wide)
                        SizedBox(
                          height: 380,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: curveCard),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: now),
                            ],
                          ),
                        )
                      else ...[
                        SizedBox(height: 360, child: curveCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 380, child: now),
                      ],
                      const SizedBox(height: 28),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 14),
                        child: Row(
                          children: [
                            Text('Conectadas', style: OcText.title),
                            SizedBox(width: 10),
                            OcTag('Exemplo'),
                          ],
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: .78,
                            ),
                        itemCount: _fans.length,
                        itemBuilder: (context, i) => _FanTile(
                          name: _fans[i],
                          speed: speed == null
                              ? null
                              : (speed * (i == 0 ? 1 : .85)).clamp(0, 100),
                          spin: spin * (i == 0 ? 1.1 : .9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CurveCard extends StatelessWidget {
  const _CurveCard({
    required this.curve,
    required this.temp,
    required this.speed,
    required this.source,
    required this.gpu,
    required this.cpuAvailable,
    required this.onSource,
  });
  final _Curve curve;
  final double? temp;
  final double? speed;
  final String source;
  final bool gpu;
  final bool cpuAvailable;
  final ValueChanged<bool> onSource;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Curva',
            trailing: Tooltip(
              message: cpuAvailable
                  ? ''
                  : 'A temperatura da CPU pede o modo administrador',
              child: OcSegmented<bool>(
                value: gpu,
                options: const [(false, 'CPU'), (true, 'GPU')],
                onChanged: onSource,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: temp ?? -1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _CurvePainter(
                  curve: curve,
                  temp: temp == null ? null : t,
                  label: temp == null ? null : source,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.curve,
    required this.temp,
    required this.label,
    required this.color,
  });
  final _Curve curve;
  final double? temp;
  final String? label;
  final Color color;

  static const _tMin = 20.0, _tMax = 100.0;
  static const _left = 40.0, _bottom = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left;
    final h = size.height - _bottom;
    Offset at(double t, double s) =>
        Offset(_left + (t - _tMin) / (_tMax - _tMin) * w, h * (1 - s / 100));
    void text(String s, Offset o, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: OcText.caption),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right
          ? o.dx - tp.width
          : align == TextAlign.center
          ? o.dx - tp.width / 2
          : o.dx;
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    final grid = Paint()
      ..color = Oc.line
      ..strokeWidth = 1;
    for (var s = 0; s <= 100; s += 25) {
      final y = at(_tMin, s.toDouble()).dy;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      text('$s%', Offset(_left - 10, y), align: TextAlign.right);
    }
    for (var t = 20; t <= 100; t += 20) {
      final x = at(t.toDouble(), 0).dx;
      text('$t °C', Offset(x, h + 16), align: TextAlign.center);
    }

    final points = [for (final (t, s) in curve) at(t, s)];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    for (final p in points) {
      canvas.drawCircle(p, 7, Paint()..color = Oc.panel);
      canvas.drawCircle(
        p,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    }

    final t = temp;
    if (t != null) {
      final clamped = t.clamp(_tMin, _tMax);
      double speed = curve.first.$2;
      for (var i = 1; i < curve.length; i++) {
        final (t1, s1) = curve[i];
        final (t0, s0) = curve[i - 1];
        if (clamped <= t1) {
          speed = s0 + (s1 - s0) * (clamped - t0) / (t1 - t0);
          break;
        }
        speed = s1;
      }
      final p = at(clamped, speed);
      final dash = Paint()
        ..color = Oc.textTertiary
        ..strokeWidth = 1;
      for (var y = 0.0; y < h; y += 6) {
        canvas.drawLine(
          Offset(p.dx, y),
          Offset(p.dx, math.min(y + 3, h)),
          dash,
        );
      }
      canvas.drawCircle(p, 9, Paint()..color = color.withValues(alpha: .25));
      canvas.drawCircle(p, 5, Paint()..color = Oc.text);
      final tp = TextPainter(
        text: TextSpan(
          text: '$label ${t.round()} °C',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Oc.bg,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            p.dx.clamp(
              _left + tp.width / 2 + 10,
              size.width - tp.width / 2 - 10,
            ),
            10,
          ),
          width: tp.width + 18,
          height: 22,
        ),
        const Radius.circular(11),
      );
      canvas.drawRRect(box, Paint()..color = Oc.text);
      tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.curve != curve ||
      old.temp != temp ||
      old.color != color ||
      old.label != label;
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.speed,
    required this.spin,
    required this.mode,
    required this.zeroRpm,
    required this.onZeroRpm,
  });
  final double? speed;
  final double spin;
  final String mode;
  final bool zeroRpm;
  final ValueChanged<bool> onZeroRpm;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OcCardTitle('Agora'),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            speed == null ? '—' : '${speed!.round()}',
                            style: const TextStyle(
                              fontFamily: Oc.fontDisplay,
                              fontSize: 56,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.8,
                              height: 1,
                              color: Oc.text,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '%',
                            style: TextStyle(
                              fontFamily: Oc.fontDisplay,
                              fontSize: 20,
                              color: Oc.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(mode, style: OcText.secondary),
                    ],
                  ),
                ),
                FanGlyph(color: accent, size: 150, speed: spin),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Parar quando frio', style: OcText.label),
              ),
              OcSwitch(value: zeroRpm, onChanged: onZeroRpm),
            ],
          ),
        ],
      ),
    );
  }
}

class _FanTile extends StatelessWidget {
  const _FanTile({required this.name, required this.speed, required this.spin});
  final String name;
  final double? speed;
  final double spin;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: OcText.label),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) => FanGlyph(
                  color: accent,
                  size: math.min(c.maxWidth, c.maxHeight) * .86,
                  speed: spin,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speed == null ? '—' : '${speed!.round()}',
                style: OcText.pageTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(width: 3),
              const Text('%', style: OcText.caption),
              const Spacer(),
              const Text('— RPM', style: OcText.caption),
            ],
          ),
        ],
      ),
    );
  }
}
