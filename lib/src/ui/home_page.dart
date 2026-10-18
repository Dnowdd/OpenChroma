import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../effects/effect_library.dart';
import '../engine/engine.dart';
import '../fans/fan_service.dart';
import '../monitor/system_monitor.dart';
import 'accent.dart';
import 'devices_page.dart';
import 'effects_page.dart' show EffectArtwork;
import 'fan_glyph.dart';
import 'fans_page.dart' show fanSpin;
import 'shell.dart' show Pages;
import 'theme.dart';
import 'widgets.dart';

/// The start page: the light that is on, the PC's vitals, what needs
/// attention, and quick access to everything else.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.engine,
    required this.monitor,
    required this.fans,
    required this.active,
    required this.onNavigate,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;
  final bool active;
  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void dispose() {
    widget.monitor.setActive(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.monitor,
    builder: (context, _) {
      final s = widget.monitor.snapshot;
      final alerts = s == null ? <_Alert>[] : _alerts(s);
      return LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1150;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 24),
            children: [
              _Header(snapshot: s, alerts: alerts.length),
              ..._grid(s, alerts, wide: wide),
            ],
          );
        },
      );
    },
  );

  List<Widget> _grid(
    SystemSnapshot? s,
    List<_Alert> alerts, {
    required bool wide,
  }) {
    final go = widget.onNavigate;
    final hero = _LightingHero(
      engine: widget.engine,
      onOpen: () => go(Pages.lighting),
    );
    const profiles = _ProfilesCard();
    final vitals = _vitalTiles(s, () => go(Pages.performance));
    final alertsCard = _AlertsCard(
      alerts: alerts,
      loading: s == null,
      onOpen: () => go(Pages.performance),
    );
    final fans = _FansCard(fans: widget.fans, onOpen: () => go(Pages.fans));
    final reactive = _ReactiveLightCard(snapshot: s);
    final devices = _DevicesCard(
      engine: widget.engine,
      onOpen: () => go(Pages.devices),
    );
    const assistant = _AssistantCard();

    const gap = 16.0;
    Widget row(double height, List<(int, Widget)> items) => SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(flex: items[i].$1, child: items[i].$2),
          ],
        ],
      ),
    );
    Widget box(double height, Widget child) =>
        SizedBox(height: height, child: child);
    const space = SizedBox(height: gap);

    if (wide) {
      return [
        row(340, [(2, hero), (1, profiles)]),
        space,
        row(176, [for (final v in vitals) (1, v)]),
        space,
        row(268, [(1, alertsCard), (1, fans), (1, reactive)]),
        space,
        row(300, [(2, assistant), (1, devices)]),
      ];
    }
    return [
      box(320, hero),
      space,
      box(250, profiles),
      space,
      row(176, [(1, vitals[0]), (1, vitals[1])]),
      space,
      row(176, [(1, vitals[2]), (1, vitals[3])]),
      space,
      box(268, alertsCard),
      space,
      row(268, [(1, fans), (1, reactive)]),
      space,
      box(300, assistant),
      space,
      box(300, devices),
    ];
  }
}

// ---------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.alerts});
  final SystemSnapshot? snapshot;
  final int alerts;

  static const _weekdays = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 5
        ? 'Boa noite'
        : now.hour < 12
        ? 'Bom dia'
        : now.hour < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final status = snapshot == null
        ? 'Lendo os sensores…'
        : alerts == 0
        ? 'Tudo certo com o seu PC.'
        : alerts == 1
        ? '1 aviso pede atenção.'
        : '$alerts avisos pedem atenção.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: OcText.pageTitle.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text(status, style: OcText.secondary.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _Clock(),
              const SizedBox(height: 2),
              Text(
                '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}',
                style: OcText.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The time, updated on each minute.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() {});
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return Text(
      '${two(now.hour)}:${two(now.minute)}',
      style: const TextStyle(
        fontFamily: Oc.fontDisplay,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: -.4,
        color: Oc.text,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ---------------------------------------------------------------- Lighting

class _LightingHero extends StatelessWidget {
  const _LightingHero({required this.engine, required this.onOpen});
  final Engine engine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final effect = engine.currentEffect;
    final devices = engine.devices.values
        .where((d) => d.status == 'running')
        .length;
    return ClipRRect(
      borderRadius: Oc.r24,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LiveCanvas(
            engine: engine,
            fallback: effect == null
                ? null
                : _EffectCover(engine: engine, effect: effect),
          ),
          // Keep the text readable over any light.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, .55, 1],
                colors: [
                  Color(0xE6000000),
                  Color(0x33000000),
                  Color(0x22000000),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: _Glass(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OcStatusDot(color: accent, size: 7),
                  const SizedBox(width: 8),
                  const Text(
                    'Ao vivo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Tooltip(
              message: 'Abrir iluminação',
              child: Hover(
                onTap: onOpen,
                builder: (context, h) => AnimatedContainer(
                  duration: Oc.fast,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: h
                        ? Colors.white
                        : Colors.black.withValues(alpha: .35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 19,
                    color: h ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        effect?.title ?? 'Nenhum efeito',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Oc.fontDisplay,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        devices == 1
                            ? 'Em 1 dispositivo'
                            : 'Em $devices dispositivos',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _Glass(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.light_mode_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 190,
                        child: SliderTheme(
                          data: SliderTheme.of(context)
                              .copyWith(inactiveTrackColor: Colors.white24),
                          child: OcSlider(
                            value: engine.brightness.toDouble(),
                            min: 0,
                            max: 100,
                            suffix: '%',
                            activeColor: Colors.white,
                            onChanged: (v) => engine.setBrightness(v.round()),
                          ),
                        ),
                      ),
                    ],
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

/// The effect's cover (or generated artwork), dimmed, for when the live
/// light is off.
class _EffectCover extends StatelessWidget {
  const _EffectCover({required this.engine, required this.effect});
  final Engine engine;
  final EffectInfo effect;

  @override
  Widget build(BuildContext context) {
    final path = engine.thumbnailFor(effect);
    return Opacity(
      opacity: .55,
      child: path == null
          ? EffectArtwork(seed: effect.title)
          : Image.file(File(path), fit: BoxFit.cover),
    );
  }
}

/// A translucent dark pill for controls laid over the live light.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.height = 32,
  });
  final Widget child;
  final EdgeInsets padding;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: padding,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: Oc.pill,
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------- Profiles

class _ProfilesCard extends StatefulWidget {
  const _ProfilesCard();

  @override
  State<_ProfilesCard> createState() => _ProfilesCardState();
}

class _ProfilesCardState extends State<_ProfilesCard> {
  int _selected = 0;

  static const _profiles = [
    (Icons.sports_esports_outlined, 'Jogo'),
    (Icons.work_outline_rounded, 'Trabalho'),
    (Icons.nightlight_outlined, 'Noite'),
    (Icons.power_settings_new_rounded, 'Desligado'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OcCardTitle('Perfis', trailing: OcTag('Em breve')),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 2; r++) ...[
                  if (r > 0) const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < 2; c++) ...[
                          if (c > 0) const SizedBox(width: 10),
                          Expanded(child: _tile(r * 2 + c, accent)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int i, Color accent) => Hover(
    onTap: () => setState(() => _selected = i),
    builder: (context, h) {
      final on = _selected == i;
      final fg = on ? onAccent(accent) : Oc.text;
      return AnimatedContainer(
        duration: Oc.smooth,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? accent : (h ? Oc.hover : Oc.raised),
          borderRadius: Oc.r12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_profiles[i].$1, size: 20, color: fg),
            const Spacer(),
            Text(
              _profiles[i].$2,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- Vitals

enum _Level {
  normal('Normal', Oc.success),
  warm('Quente', Oc.warning),
  hot('Muito quente', Oc.danger);

  const _Level(this.label, this.color);
  final String label;
  final Color color;

  static _Level of(double t, double warm, double hot) => t >= hot
      ? _Level.hot
      : t >= warm
      ? _Level.warm
      : _Level.normal;
}

_Level _cpuLevel(double t) => _Level.of(t, 75, 88);
_Level _gpuLevel(double t) => _Level.of(t, 75, 85);
_Level _ssdLevel(double t) => _Level.of(t, 60, 70);

List<Widget> _vitalTiles(SystemSnapshot? s, VoidCallback onOpen) {
  final cpu = s?.cpu;
  final gpu = s?.gpus.firstOrNull;
  final mem = s?.memory;
  final volume =
      s?.volumes.where((v) => v.letter == 'C').firstOrNull ??
      s?.volumes.firstOrNull;
  return [
    _VitalTile(
      icon: Icons.memory_rounded,
      label: 'CPU',
      value: cpu?.temp != null
          ? _fmt(cpu!.temp!, 0)
          : (cpu?.usage != null ? _fmt(cpu!.usage!, 0) : '—'),
      unit: cpu?.temp != null ? '°C' : '%',
      detail: cpu == null
          ? ''
          : cpu.temp != null
          ? 'Uso ${_fmt(cpu.usage ?? 0, 0)}%'
          : 'Uso · temperatura pede admin',
      percent: cpu?.temp ?? cpu?.usage,
      level: cpu?.temp != null ? _cpuLevel(cpu!.temp!) : null,
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.videogame_asset_outlined,
      label: 'GPU',
      value: gpu?.temp != null ? _fmt(gpu!.temp!, 0) : '—',
      unit: '°C',
      detail: gpu == null
          ? ''
          : [
              if (gpu.usage != null) 'Uso ${_fmt(gpu.usage!, 0)}%',
              if (gpu.power != null) '${_fmt(gpu.power!, 0)} W',
            ].join(' · '),
      percent: gpu?.temp,
      level: gpu?.temp != null ? _gpuLevel(gpu!.temp!) : null,
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.developer_board_outlined,
      label: 'Memória',
      value: mem == null ? '—' : _fmt(mem.percent, 0),
      unit: '%',
      detail: mem == null ? '' : '${_fmtGb(mem.used)} de ${_fmtGb(mem.total)}',
      percent: mem?.percent,
      level: mem == null ? null : (mem.percent >= 90 ? _Level.warm : null),
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.storage_rounded,
      label: 'Armazenamento',
      value: volume == null ? '—' : _fmt(volume.free / _gb, 0),
      unit: 'GB livres',
      detail: volume == null
          ? ''
          : '${volume.letter}: · ${_fmt(volume.percent, 0)}% usado',
      percent: volume?.percent,
      level: volume == null
          ? null
          : (volume.percent >= 90 ? _Level.warm : null),
      onTap: onOpen,
    ),
  ];
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.detail,
    required this.percent,
    required this.level,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String detail;
  final double? percent;

  /// Shown as a colored dot with its label; null when there is nothing to
  /// flag.
  final _Level? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Oc.raised,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: Oc.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: OcText.secondary.copyWith(color: Oc.text),
                ),
              ),
              if (level != null)
                Tooltip(
                  message: level!.label,
                  child: OcStatusDot(color: level!.color, size: 8),
                ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: Oc.fontDisplay,
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                  height: 1,
                  color: Oc.text,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  unit,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Oc.fontDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Oc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Meter(
            percent: percent ?? 0,
            color: level != null && level != _Level.normal
                ? level!.color
                : accent,
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OcText.caption,
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: Oc.pill,
    child: SizedBox(
      height: 5,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Oc.raised)),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            widthFactor: (percent / 100).clamp(0, 1),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: Oc.pill),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- Alerts

class _Alert {
  const _Alert(this.icon, this.title, this.detail, this.color);
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
}

List<_Alert> _alerts(SystemSnapshot s) {
  final out = <_Alert>[];
  void temp(String what, double? t, _Level Function(double) level) {
    if (t == null) return;
    final l = level(t);
    if (l == _Level.normal) return;
    out.add(
      _Alert(
        Icons.thermostat_rounded,
        '$what ${l == _Level.hot ? 'muito quente' : 'quente'}',
        '${_fmt(t, 0)} °C agora',
        l.color,
      ),
    );
  }

  temp('CPU', s.cpu.temp, _cpuLevel);
  temp('GPU', s.gpus.firstOrNull?.temp, _gpuLevel);
  for (final d in s.disks) {
    temp(d.model.isEmpty ? 'Disco' : d.model, d.temp, _ssdLevel);
  }
  if (s.memory.percent >= 90) {
    out.add(
      _Alert(
        Icons.developer_board_outlined,
        'Memória quase cheia',
        '${_fmt(s.memory.percent, 0)}% em uso · ${_fmtGb(s.memory.available)} livres',
        s.memory.percent >= 95 ? Oc.danger : Oc.warning,
      ),
    );
  }
  for (final v in s.volumes) {
    if (v.percent < 90) continue;
    out.add(
      _Alert(
        Icons.storage_rounded,
        'Disco ${v.letter}: quase cheio',
        '${_fmtGb(v.free)} livres de ${_fmtGb(v.total)}',
        v.percent >= 95 ? Oc.danger : Oc.warning,
      ),
    );
  }
  return out;
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.alerts,
    required this.loading,
    required this.onOpen,
  });
  final List<_Alert> alerts;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => OcCard(
    onTap: onOpen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcCardTitle(
          'Avisos',
          trailing: alerts.isEmpty ? null : OcTag('${alerts.length}'),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: loading
              ? const SizedBox.shrink()
              : alerts.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 38,
                      color: Oc.success,
                    ),
                    SizedBox(height: 10),
                    Text('Tudo certo', style: OcText.label),
                  ],
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = alerts[i];
                    return Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: .14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(a.icon, size: 18, color: a.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OcText.label,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OcText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Fans

class _FansCard extends StatelessWidget {
  const _FansCard({required this.fans, required this.onOpen});
  final FanService fans;
  final VoidCallback onOpen;

  static const _modes = [
    (FanProfile.silent, 'Silencioso'),
    (FanProfile.balanced, 'Equilibrado'),
    (FanProfile.turbo, 'Turbo'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return ListenableBuilder(
      listenable: fans,
      builder: (context, _) {
        final connected = [
          for (final f in fans.snapshot?.fans ?? const <FanReading>[])
            if (fans.isConnected(f)) f,
        ];
        final rpms = [for (final f in connected) f.rpm ?? 0];
        final fastest = rpms.isEmpty ? null : rpms.reduce(math.max);
        return OcCard(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OcCardTitle('Ventoinhas'),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    FanGlyph(color: accent, size: 104, speed: fanSpin(fastest)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _modes.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _ModeButton(
                              label: _modes[i].$2,
                              selected: fans.profile == _modes[i].$1,
                              onTap: () => fans.setProfile(_modes[i].$1),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (connected.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  [
                    connected.length == 1
                        ? '1 ventoinha'
                        : '${connected.length} ventoinhas',
                    if (fastest != null && fastest > 0)
                      'até ${fastest.round()} RPM',
                  ].join(' · '),
                  style: OcText.caption,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return Hover(
      onTap: onTap,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.smooth,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? accent : (h ? Oc.hover : Oc.raised),
          borderRadius: Oc.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? onAccent(accent) : Oc.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Reactive

class _ReactiveLightCard extends StatefulWidget {
  const _ReactiveLightCard({required this.snapshot});
  final SystemSnapshot? snapshot;

  @override
  State<_ReactiveLightCard> createState() => _ReactiveLightCardState();
}

class _ReactiveLightCardState extends State<_ReactiveLightCard> {
  bool _on = false;
  bool _gpu = true;

  static const _lo = 30.0;
  static const _hi = 90.0;
  static const _scale = [
    Color(0xFF60A5FA),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFF87171),
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final temp = _gpu ? s?.gpus.firstOrNull?.temp : s?.cpu.temp;
    final t = temp == null
        ? null
        : ((temp - _lo) / (_hi - _lo)).clamp(0.0, 1.0);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Luz reativa',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OcTag('Em breve'),
                const SizedBox(width: 10),
                OcSwitch(value: _on, onChanged: (v) => setState(() => _on = v)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A cor dos LEDs segue a temperatura.',
            style: OcText.secondary,
          ),
          const Spacer(),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 11,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: Oc.pill,
                        gradient: const LinearGradient(colors: _scale),
                      ),
                    ),
                  ),
                  if (t != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      left: t * (c.maxWidth - 30),
                      top: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Oc.text,
                          border: Border.all(color: Oc.panel, width: 4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${_lo.round()} °C', style: OcText.caption),
              const Spacer(),
              if (temp != null)
                Text(
                  '${_gpu ? 'GPU' : 'CPU'} ${_fmt(temp, 0)} °C',
                  style: OcText.caption.copyWith(color: Oc.text),
                ),
              const Spacer(),
              Text('${_hi.round()} °C', style: OcText.caption),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OcSegmented<bool>(
              value: _gpu,
              options: const [(false, 'CPU'), (true, 'GPU')],
              onChanged: (v) => setState(() => _gpu = v),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Devices

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.engine, required this.onOpen});
  final Engine engine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final devices = engine.devices.values.toList();
    return OcCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Dispositivos',
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Oc.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text(
                      engine.scanning ? 'Procurando…' : 'Nenhum dispositivo',
                      style: OcText.secondary,
                    ),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      final (label, color) = switch (d.status) {
                        'running' => ('Conectado', Oc.success),
                        'starting' => ('Iniciando', Oc.warning),
                        _ => ('Com problema', Oc.danger),
                      };
                      return Row(
                        children: [
                          DeviceThumb(url: d.imageUrl, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OcText.label,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    OcStatusDot(color: color, size: 6),
                                    const SizedBox(width: 6),
                                    Text(label, style: OcText.caption),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Assistant

class _AssistantCard extends StatefulWidget {
  const _AssistantCard();

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  final _input = TextEditingController();
  String? _asked;

  static const _suggestions = [
    'Por que meu PC tá lento?',
    'O que tá esquentando a GPU?',
    'Cria um efeito azul calmo',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    setState(() => _asked = q);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      HSVColor.fromColor(accent)
                          .withHue((HSVColor.fromColor(accent).hue + 60) % 360)
                          .toColor(),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: onAccent(accent),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: OcCardTitle('Assistente', trailing: OcTag('Em breve')),
              ),
            ],
          ),
          const Spacer(),
          if (_asked == null)
            Text(
              'Pergunte qualquer coisa sobre o seu PC.',
              style: OcText.title.copyWith(
                fontSize: 22,
                color: Oc.textSecondary,
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerRight,
              child: _Bubble(text: _asked!, mine: true, accent: accent),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _Bubble(
                text:
                    'Ainda estou aprendendo. Logo vou responder isso por aqui.',
                mine: false,
                accent: accent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                Hover(
                  onTap: () => _send(s),
                  builder: (context, h) => AnimatedContainer(
                    duration: Oc.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: h ? Oc.hover : Oc.raised,
                      borderRadius: Oc.pill,
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(fontSize: 12.5, color: Oc.text),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 18, right: 5),
            decoration: BoxDecoration(
              color: Oc.raised,
              borderRadius: Oc.pill,
              border: Border.all(color: Oc.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 13.5, color: Oc.text),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Pergunte algo…',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: Oc.textTertiary,
                      ),
                    ),
                  ),
                ),
                Hover(
                  onTap: _send,
                  builder: (context, h) => Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: h ? Colors.white : accent,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 19,
                      color: h ? Oc.bg : onAccent(accent),
                    ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, required this.accent});
  final String text;
  final bool mine;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 420),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: mine ? accent : Oc.raised,
      borderRadius: Oc.r12,
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: mine ? onAccent(accent) : Oc.text),
    ),
  );
}

// ---------------------------------------------------------------- Format

const _gb = 1024.0 * 1024 * 1024;

String _fmt(double v, int decimals) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String _fmtGb(double bytes) => '${_fmt(bytes / _gb, 1)} GB';
