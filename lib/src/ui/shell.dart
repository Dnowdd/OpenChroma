import 'package:flutter/material.dart';

import '../effects/effect_host.dart';
import '../engine/engine.dart';
import 'devices_page.dart';
import 'effects_page.dart';
import 'layout_page.dart';
import 'monitor_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.engine, this.initialPage});
  final Engine engine;
  final int? initialPage;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // OC_PAGE opens a given page on launch (handy for screenshots).
  late int _page = widget.initialPage ?? const int.fromEnvironment('OC_PAGE');

  static const _nav = [
    (Icons.grid_view_rounded, 'Efeitos'),
    (Icons.devices_other_outlined, 'Dispositivos'),
    (Icons.space_dashboard_outlined, 'Layout'),
    (Icons.monitor_heart_outlined, 'Monitor'),
    (Icons.tune_rounded, 'Configurações'),
  ];

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return Scaffold(
      body: Stack(
        children: [
          // Renders effect covers off to the side; the UI covers it.
          Positioned(left: 0, top: 0, child: CoverBaker(engine: engine)),
          Positioned.fill(
            child: ColoredBox(
              color: Oc.bg,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListenableBuilder(
                          listenable: engine,
                          builder: (context, _) => _Sidebar(
                            engine: engine,
                            index: _page,
                            items: _nav,
                            onSelect: (i) => setState(() => _page = i),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: engine,
                            builder: (context, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (engine.conflicts.isNotEmpty)
                                  _ConflictBanner(names: engine.conflicts),
                                Expanded(
                                  child: IndexedStack(
                                    index: _page,
                                    children: [
                                      EffectsPage(engine: engine),
                                      DevicesPage(engine: engine),
                                      LayoutPage(engine: engine),
                                      MonitorPage(
                                        engine: engine,
                                        active: _page == 3,
                                      ),
                                      SettingsPage(engine: engine),
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
                  NowPlayingBar(
                    engine: engine,
                    onOpenEffects: () => setState(() => _page = 0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.engine,
    required this.index,
    required this.items,
    required this.onSelect,
  });
  final Engine engine;
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = engine.devices.values
        .where((d) => d.status == 'running')
        .length;
    return Container(
      width: 220,
      color: Oc.bg,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 24),
            child: Row(
              children: [
                _LogoMark(),
                SizedBox(width: 10),
                Text(
                  'OpenChroma',
                  style: TextStyle(
                    fontFamily: Oc.fontDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Oc.text,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _NavItem(
              icon: items[i].$1,
              label: items[i].$2,
              selected: index == i,
              trailing: i == 1 && active > 0 ? '$active' : null,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                OcStatusDot(
                  color: engine.scanning
                      ? Oc.warning
                      : (active > 0 ? Oc.success : Oc.textTertiary),
                  size: 6,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    engine.scanning
                        ? 'Carregando plugins…'
                        : active == 1
                        ? '1 dispositivo conectado'
                        : '$active dispositivos conectados',
                    style: OcText.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A minimal mark: a ring with a lit segment.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Oc.lineStrong,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.9,
      2.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = Oc.text,
    );
    canvas.drawCircle(c, 2.2, Paint()..color = Oc.text);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Hover(
      onTap: onTap,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Oc.raised : (h ? Oc.panel : Colors.transparent),
          borderRadius: Oc.r6,
          border: Border.all(color: selected ? Oc.line : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected || h ? Oc.text : Oc.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected || h ? Oc.text : Oc.textSecondary,
                ),
              ),
            ),
            if (trailing != null) Text(trailing!, style: OcText.caption),
          ],
        ),
      ),
    ),
  );
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
    decoration: BoxDecoration(
      color: Oc.warning.withValues(alpha: .07),
      border: Border(
        bottom: BorderSide(color: Oc.warning.withValues(alpha: .2)),
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: Oc.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${names.join(', ')} está em execução. ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(
                  text:
                      'Dois programas controlando os mesmos LEDs fazem as cores piscarem. '
                      'Feche-o, inclusive na bandeja do sistema.',
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5, color: Oc.warning),
          ),
        ),
      ],
    ),
  );
}

/// Persistent bottom bar with the running effect. It hosts the WebView that
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
  Widget build(BuildContext context) => Container(
    height: 76,
    decoration: const BoxDecoration(
      color: Oc.bg,
      border: Border(top: BorderSide(color: Oc.line)),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -1,
          child: LightStrip(engine: engine),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: Oc.r6,
                child: Container(
                  width: 80,
                  height: 50,
                  foregroundDecoration: BoxDecoration(
                    borderRadius: Oc.r6,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
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
                                engine.currentEffect?.title ?? 'Nenhum efeito',
                                overflow: TextOverflow.ellipsis,
                                style: OcText.label.copyWith(
                                  decoration: h
                                      ? TextDecoration.underline
                                      : null,
                                  decorationColor: Oc.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const OcStatusDot(color: Oc.success, size: 5),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ao vivo em ${_devicesLabel(engine)}',
                                    style: OcText.caption,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.wb_sunny_outlined,
                        size: 16,
                        color: Oc.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 200,
                        child: OcSlider(
                          value: engine.brightness.toDouble(),
                          min: 0,
                          max: 100,
                          suffix: '%',
                          onChanged: (v) => engine.setBrightness(v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _devicesLabel(Engine e) {
    final n = e.devices.values.where((d) => d.status == 'running').length;
    return n == 1 ? '1 dispositivo' : '$n dispositivos';
  }
}

/// A hairline that shows the middle row of the effect canvas, with a soft
/// glow, so the chrome always carries the current light.
class LightStrip extends StatelessWidget {
  const LightStrip({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CanvasFrame?>(
    valueListenable: engine.frameNotifier,
    builder: (context, f, _) {
      if (f == null) return const SizedBox(height: 1);
      const samples = 48;
      final y = f.height ~/ 2;
      final colors = <Color>[
        for (var i = 0; i < samples; i++)
          () {
            final x = (i * (f.width - 1) / (samples - 1)).round();
            final p = (y * f.width + x) * 3;
            return Color.fromARGB(255, f.rgb[p], f.rgb[p + 1], f.rgb[p + 2]);
          }(),
      ];
      final gradient = LinearGradient(colors: colors);
      return SizedBox(
        height: 14,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
            Positioned.fill(
              top: 1,
              child: Opacity(
                opacity: .12,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Oc.bg],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
