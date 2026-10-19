import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../ai/assistant.dart';
import '../alerts/alert_service.dart';
import '../effects/effect_host.dart';
import '../checkup/checkup.dart';
import '../engine/engine.dart';
import '../fans/fan_service.dart';
import '../monitor/system_monitor.dart';
import '../system/launch_settings.dart';
import 'accent.dart';
import 'checkup_page.dart';
import 'decor_clock.dart';
import 'devices_page.dart';
import 'effects_page.dart';
import 'fans_page.dart';
import 'home_page.dart';
import 'layout_page.dart';
import 'monitor_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';
import 'window_frame.dart';

/// Page indices, also used by --page=N and OC_PAGE.
abstract final class Pages {
  static const home = 0;
  static const lighting = 1;
  static const devices = 2;
  static const fans = 3;
  static const performance = 4;
  static const settings = 5;
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.engine,
    required this.monitor,
    required this.fans,
    required this.alerts,
    required this.ai,
    required this.assistant,
    this.initialPage,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;
  final AlertService alerts;
  final AiService ai;
  final Assistant assistant;
  final int? initialPage;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // OC_PAGE opens a given page on launch (handy for screenshots).
  late int _page = (widget.initialPage ?? const int.fromEnvironment('OC_PAGE'))
      .clamp(0, Pages.settings);
  late final _accent = AccentController(widget.engine);
  SystemMonitor get _monitor => widget.monitor;
  late final _checkup = CheckupService(
    monitor: widget.monitor,
    fans: widget.fans,
  );

  static const _nav = [
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Iluminação'),
    (Icons.keyboard_alt_outlined, Icons.keyboard_alt, 'Dispositivos'),
    (Icons.air_rounded, Icons.air_rounded, 'Ventoinhas'),
    (Icons.speed_outlined, Icons.speed_rounded, 'Desempenho'),
  ];

  // Pages only sample the system monitor while someone can see them; in
  // the tray the fans keep their own subscription.
  bool _visible = true;
  late final _lifecycle = AppLifecycleListener(
    onHide: () => setState(() => _visible = false),
    onShow: () => setState(() => _visible = true),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _checkup.dispose();
    _accent.dispose();
    super.dispose();
  }

  bool _shows(int page) => _visible && _page == page;

  void _go(int page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return LiveAccent(
      controller: _accent,
      child: Scaffold(
        backgroundColor: Oc.bg,
        body: Stack(
          children: [
            // Renders effect covers off to the side; the UI covers it.
            Positioned(left: 0, top: 0, child: CoverBaker(engine: engine)),
            Positioned.fill(
              child: ColoredBox(
                color: Oc.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TitleBar(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListenableBuilder(
                            listenable: engine,
                            builder: (context, _) => _Rail(
                              engine: engine,
                              index: _page,
                              items: _nav,
                              onSelect: _go,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListenableBuilder(
                                  listenable: engine,
                                  builder: (context, _) =>
                                      engine.conflicts.isEmpty
                                      ? const SizedBox.shrink()
                                      : _ConflictBanner(
                                          names: engine.conflicts,
                                        ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: webviewProblem,
                                  builder: (context, problem, _) =>
                                      problem == null
                                      ? const SizedBox.shrink()
                                      : const _WebviewBanner(),
                                ),
                                Expanded(
                                  // Content fades out above the player
                                  // instead of being cut off: a gradient to
                                  // the background on top, which looks the
                                  // same as masking the page but does not
                                  // re-render it offscreen on every frame.
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ListenableBuilder(
                                          listenable: engine,
                                          builder: (context, _) => PageStack(
                                            index: _page,
                                            children: [
                                              HomePage(
                                                engine: engine,
                                                monitor: _monitor,
                                                fans: widget.fans,
                                                assistant: widget.assistant,
                                                active: _shows(Pages.home),
                                                onNavigate: _go,
                                              ),
                                              _LightingPage(engine: engine),
                                              DevicesPage(engine: engine),
                                              FansPage(
                                                fans: widget.fans,
                                                active: _shows(Pages.fans),
                                                onRestartAsAdmin: () =>
                                                    restartAsAdmin(
                                                      page: Pages.fans,
                                                      shutdown: engine.shutdown,
                                                    ),
                                              ),
                                              _PerformancePage(
                                                engine: engine,
                                                monitor: _monitor,
                                                checkup: _checkup,
                                                ai: widget.ai,
                                                active: _shows(
                                                  Pages.performance,
                                                ),
                                              ),
                                              SettingsPage(
                                                engine: engine,
                                                ai: widget.ai,
                                                alerts: widget.alerts,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: 28,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Color(0x000C0C0E),
                                                  Oc.bg,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                NowPlayingBar(
                                  engine: engine,
                                  onOpenEffects: () => _go(Pages.lighting),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Effects and their placement on the canvas, under one destination.
class _LightingPage extends StatefulWidget {
  const _LightingPage({required this.engine});
  final Engine engine;

  @override
  State<_LightingPage> createState() => _LightingPageState();
}

class _LightingPageState extends State<_LightingPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: Oc.headerInsets,
        child: Row(
          children: [
            Text('Iluminação', style: OcText.pageTitle.copyWith(fontSize: 28)),
            const Spacer(),
            OcSegmented<int>(
              value: _tab,
              options: const [(0, 'Efeitos'), (1, 'Layout')],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ],
        ),
      ),
      Expanded(
        child: PageStack(
          index: _tab,
          children: [
            EffectsPage(engine: widget.engine),
            LayoutPage(engine: widget.engine),
          ],
        ),
      ),
    ],
  );
}

/// Live monitor and checkup, under one destination.
class _PerformancePage extends StatefulWidget {
  const _PerformancePage({
    required this.engine,
    required this.monitor,
    required this.checkup,
    required this.ai,
    required this.active,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final CheckupService checkup;
  final AiService ai;
  final bool active;

  @override
  State<_PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<_PerformancePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      OcSegmented<int>(
        value: _tab,
        options: const [(0, 'Monitor'), (1, 'Diagnóstico')],
        onChanged: (v) => setState(() => _tab = v),
      ),
    ];
    return PageStack(
      index: _tab,
      children: [
        MonitorPage(
          engine: widget.engine,
          monitor: widget.monitor,
          active: widget.active && _tab == 0,
          headerActions: tabs,
        ),
        CheckupPage(
          checkup: widget.checkup,
          ai: widget.ai,
          headerActions: tabs,
          onRestartAsAdmin: () => restartAsAdmin(
            page: Pages.performance,
            shutdown: widget.engine.shutdown,
          ),
        ),
      ],
    );
  }
}

/// Navigation: a column of round icon buttons, the selected one lit with
/// the live accent.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.engine,
    required this.index,
    required this.items,
    required this.onSelect,
  });
  final Engine engine;
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = engine.devices.values
        .where((d) => d.status == 'running')
        .length;
    final elevated = Elevation.isElevated;
    return SizedBox(
      width: 88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
        child: Column(
          children: [
            _RailGroup(
              children: [
                for (var i = 0; i < items.length; i++)
                  _RailButton(
                    icon: index == i ? items[i].$2 : items[i].$1,
                    label: items[i].$3,
                    selected: index == i,
                    badge: i == Pages.devices && active > 0 ? '$active' : null,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
            const Spacer(),
            _RailGroup(
              children: [
                _RailButton(
                  icon: Icons.tune_rounded,
                  label: 'Configurações',
                  selected: index == Pages.settings,
                  onTap: () => onSelect(Pages.settings),
                ),
                _RailButton(
                  icon: elevated
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  label: elevated
                      ? 'Modo administrador ativo'
                      : 'Reiniciar como administrador',
                  selected: false,
                  dot: elevated ? Oc.success : null,
                  onTap: elevated
                      ? null
                      : () => restartAsAdmin(
                          page: index,
                          shutdown: engine.shutdown,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RailGroup extends StatelessWidget {
  const _RailGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.pill,
      border: Border.all(color: Oc.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.dot,
  });
  final IconData icon;
  final String label;
  final bool selected;

  /// Null shows the button without hover or click.
  final VoidCallback? onTap;
  final String? badge;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return Tooltip(
      message: label,
      preferBelow: false,
      verticalOffset: 30,
      child: Hover(
        onTap: onTap,
        builder: (context, h) => Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: Oc.smooth,
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? accent
                    : (h && onTap != null ? Oc.hover : Colors.transparent),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .35),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 21,
                color: selected
                    ? onAccent(accent)
                    : (h && onTap != null ? Oc.text : Oc.textSecondary),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Oc.text,
                    borderRadius: Oc.pill,
                    border: Border.all(color: Oc.panel, width: 2),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Oc.bg,
                    ),
                  ),
                ),
              ),
            if (dot != null)
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Oc.panel, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 20, 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Oc.warning.withValues(alpha: .08),
        borderRadius: Oc.r12,
        border: Border.all(color: Oc.warning.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: Oc.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${names.join(', ')} está aberto. ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(
                    text:
                        'Dois programas nos mesmos LEDs fazem as cores '
                        'piscarem. Feche-o, inclusive na bandeja.',
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5, color: Oc.warning),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WebviewBanner extends StatelessWidget {
  const _WebviewBanner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 20, 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      decoration: BoxDecoration(
        color: Oc.warning.withValues(alpha: .08),
        borderRadius: Oc.r12,
        border: Border.all(color: Oc.warning.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: Oc.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Os efeitos precisam do Microsoft WebView2, que não está '
              'instalado neste PC.',
              style: TextStyle(fontSize: 12.5, color: Oc.warning),
            ),
          ),
          OcButton(
            label: 'Baixar o WebView2',
            icon: Icons.download_rounded,
            onPressed: () => Process.run('explorer', [
              'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
            ]),
          ),
        ],
      ),
    ),
  );
}

/// Persistent player with the running effect. It hosts the WebView that
/// renders the effect, so it is always mounted and on screen.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({
    super.key,
    required this.engine,
    required this.onOpenEffects,
  });
  final Engine engine;
  final VoidCallback onOpenEffects;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 20, 16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Oc.panel,
          borderRadius: Oc.r24,
          border: Border.all(color: Oc.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LightStrip(engine: engine),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: Oc.r10,
                      child: SizedBox(
                        width: 76,
                        height: 48,
                        child: EffectPreview(engine: engine),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: engine,
                        builder: (context, _) => Row(
                          children: [
                            Flexible(
                              child: Hover(
                                onTap: onOpenEffects,
                                builder: (context, h) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      engine.currentEffect?.title ??
                                          'Nenhum efeito',
                                      overflow: TextOverflow.ellipsis,
                                      style: OcText.label.copyWith(
                                        fontSize: 14,
                                        decoration: h
                                            ? TextDecoration.underline
                                            : null,
                                        decorationColor: Oc.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        OcStatusDot(color: accent, size: 6),
                                        const SizedBox(width: 7),
                                        Text(
                                          _devicesLabel(engine),
                                          style: OcText.caption,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.only(
                                left: 14,
                                right: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: Oc.raised,
                                borderRadius: Oc.pill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.light_mode_outlined,
                                    size: 16,
                                    color: Oc.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 210,
                                    child: OcSlider(
                                      value: engine.brightness.toDouble(),
                                      min: 0,
                                      max: 100,
                                      suffix: '%',
                                      activeColor: accent,
                                      onChanged: (v) =>
                                          engine.setBrightness(v.round()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _devicesLabel(Engine e) {
    final n = e.devices.values.where((d) => d.status == 'running').length;
    return n == 1 ? 'Ao vivo em 1 dispositivo' : 'Ao vivo em $n dispositivos';
  }
}

/// A hairline that shows the middle row of the effect canvas, with a soft
/// glow, so the chrome always carries the current light. Effect frames
/// arrive at about 30 Hz and unevenly; the strip repaints on the
/// [DecorClock] and eases its colors toward the latest frame, so it flows
/// instead of stepping.
class LightStrip extends StatefulWidget {
  const LightStrip({super.key, required this.engine});
  final Engine engine;

  @override
  State<LightStrip> createState() => _LightStripState();
}

class _LightStripState extends State<LightStrip> with DecorClockMixin {
  static const _samples = 64;

  // Current (displayed) and target colors, as RGB floats.
  final _current = Float32List(_samples * 3);
  final _target = Float32List(_samples * 3);
  final _repaint = ValueNotifier<int>(0);
  final _clock = Stopwatch()..start();
  Duration _last = Duration.zero;
  bool _hasFrame = false;

  @override
  void initState() {
    super.initState();
    widget.engine.frameNotifier.addListener(_onFrame);
    _onFrame();
  }

  @override
  void dispose() {
    widget.engine.frameNotifier.removeListener(_onFrame);
    _repaint.dispose();
    super.dispose();
  }

  void _onFrame() {
    final f = widget.engine.frameNotifier.value;
    if (f == null) return;
    final y = f.height ~/ 2;
    for (var i = 0; i < _samples; i++) {
      final x = (i * (f.width - 1) / (_samples - 1)).round();
      final p = (y * f.width + x) * 3;
      _target[i * 3] = f.rgb[p].toDouble();
      _target[i * 3 + 1] = f.rgb[p + 1].toDouble();
      _target[i * 3 + 2] = f.rgb[p + 2].toDouble();
    }
    if (!_hasFrame) {
      _current.setAll(0, _target);
      _hasFrame = true;
    }
  }

  @override
  void onDecorTick() {
    final now = _clock.elapsed;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (!_hasFrame || dt <= 0) return;
    // Exponential approach: about 70 ms to cover two thirds of the way.
    final k = 1 - math.exp(-dt.clamp(0, .1) / .07);
    var moving = false;
    for (var i = 0; i < _current.length; i++) {
      final d = _target[i] - _current[i];
      if (d.abs() > .3) moving = true;
      _current[i] += d * k;
    }
    if (moving) _repaint.value++;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: CustomPaint(
      painter: _StripPainter(_current, _repaint, () => _hasFrame),
    ),
  );
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.rgb, Listenable repaint, this.ready)
    : super(repaint: repaint);
  final Float32List rgb;
  final bool Function() ready;

  @override
  void paint(Canvas canvas, Size size) {
    if (!ready()) return;
    final n = rgb.length ~/ 3;
    final colors = <Color>[
      for (var i = 0; i < n; i++)
        Color.fromARGB(
          255,
          rgb[i * 3].round().clamp(0, 255),
          rgb[i * 3 + 1].round().clamp(0, 255),
          rgb[i * 3 + 2].round().clamp(0, 255),
        ),
    ];
    final line = Rect.fromLTWH(0, 0, size.width, 1);
    final gradient = LinearGradient(colors: colors);
    canvas.drawRect(line, Paint()..shader = gradient.createShader(line));
    // Soft glow below the line, fading into the panel.
    final glow = Rect.fromLTWH(0, 1, size.width, size.height - 1);
    canvas.saveLayer(glow, Paint());
    canvas.drawRect(
      glow,
      Paint()
        ..shader = gradient.createShader(glow)
        ..color = const Color(0x1FFFFFFF),
    );
    canvas.drawRect(
      glow,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0x00000000)],
        ).createShader(glow),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripPainter old) => false;
}
